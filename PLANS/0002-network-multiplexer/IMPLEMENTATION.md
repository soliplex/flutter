# Implementation Plan: Network Multiplexer (Run Registry)

## Overview

This plan uses vertical slicing with a "walking skeleton" approach. Slice 1
delivers immediate value by removing the cancel-on-navigate behavior. Subsequent
slices refactor toward the full Run Registry pattern.

## Slice Summary

| # | Slice | ~Lines | Customer Value |
|---|-------|--------|----------------|
| 1 | Walking skeleton - don't cancel | ~80 | Runs survive thread navigation |
| 2 | RunHandle model | ~60 | Foundation for multi-run (internal) |
| 3 | RunRegistry class | ~120 | Multi-run infrastructure (internal) |
| 4 | Migrate startRun to registry | ~100 | Same behavior, new architecture |
| 5 | Multi-thread concurrent runs | ~80 | Multiple threads can stream at once |
| 6 | Thread-aware UI subscription | ~80 | Smooth UI transitions between runs |
| 7 | Lifecycle events broadcast | ~80 | Background awareness infrastructure |
| 8 | Background cache updates | ~60 | Messages persist for backgrounded runs |
| 9 | Unread run indicators | ~120 | Visual feedback for completed runs |
| 10 | Cross-room composite key | ~50 | Runs keyed by (roomId, threadId) |
| 11 | Remove room-switch cancellation | ~40 | Full navigation independence |

## Dependency Structure

```text
[1] Walking skeleton
         │
         ▼
[2] RunHandle ──────┐
         │          │
         ▼          │
[3] RunRegistry ◄───┘
         │
         ▼
[4] Migrate startRun
         │
    ┌────┴────┐
    ▼         ▼
[5] Multi    [7] Lifecycle
    │              │
    ▼         ┌────┴────┐
[6] UI sub   ▼         ▼
    │       [8] Cache  [9] Unread
    │                   indicators
    ▼
[10] Cross-room key
    │
    ▼
[11] Room-switch
```

**Parallel from slice 4:** Slices 5-6 (multi-run path) and 7-9 (events path) can
proceed in parallel after slice 4 merges.

## Implementation Order

1. **Slice 1** - Walking skeleton (required first, immediate value)
2. **Slice 2** - RunHandle model
3. **Slice 3** - RunRegistry class
4. **Slice 4** - Migrate startRun (architecture complete)
5. **Slice 5** - Multi-thread concurrent runs (parallel with 7)
6. **Slice 7** - Lifecycle events (parallel with 5)
7. **Slice 6** - Thread-aware UI subscription
8. **Slice 8** - Background cache updates (parallel with 9)
9. **Slice 9** - Unread run indicators (parallel with 8)
10. **Slice 10** - Cross-room composite key
11. **Slice 11** - Remove room-switch cancellation

---

## Slice 1: Walking Skeleton - Don't Cancel

**Branch:** `feat/network-multiplexer/01-skeleton`

**Target:** ~80 lines (mostly test changes)

**Customer value:** User switches threads and returns to find their AI response
still streaming. No more lost work.

### What's included (minimal)

- Remove the `threadSelectionProvider` listener that calls `reset()`
- Update tests that expect reset on thread change
- Verify run continues when navigating away

### What's intentionally excluded

- RunHandle model (slice 2)
- RunRegistry (slice 3)
- Multi-run support (slice 5)
- UI subscription switching (slice 6)

### Tasks

1. Remove lines 90-96 in `active_run_notifier.dart` (the listener that resets)
2. Update `thread change behavior` test group in `active_run_notifier_test.dart`
3. Add test: "run continues when switching threads"
4. Add test: "run state preserved when returning to thread"

### Files Modified

- `lib/core/providers/active_run_notifier.dart` (remove ~6 lines)
- `test/core/providers/active_run_notifier_test.dart` (update tests)

### Tests

- Remove: "resets state when switching from one thread to another"
- Add: "run continues when switching threads"
- Add: "run state preserved when returning to thread"
- Keep: "does not reset when selecting the same thread again"
- Keep: "does not reset when initially selecting a thread"

### Acceptance Criteria

- [ ] Run continues when user navigates away from thread
- [ ] Run state is preserved when user returns
- [ ] All existing tests pass (or are updated appropriately)
- [ ] No memory leaks (run resources are still cleaned up on completion)

---

## Slice 2: RunHandle Model

**Branch:** `feat/network-multiplexer/02-run-handle`

**Target:** ~60 lines

**Customer value:** Internal refactor. Encapsulates run resources for cleaner
code and prepares for multi-run tracking.

### Tasks

1. Create `lib/core/models/run_handle.dart`
2. Define `RunHandle` class with: key (RunKey), runId, cancelToken,
   subscription, userMessageId, previousAguiState, state, isActive
3. Move dispose logic from `RunningInternalState` to `RunHandle` (idempotent)
4. Add unit tests for `RunHandle`

### Files Created

- `lib/core/models/run_handle.dart`
- `test/core/models/run_handle_test.dart`

### RunHandle API

```dart
typedef RunKey = ({String roomId, String threadId});

class RunHandle {
  RunHandle({
    required this.key,
    required this.runId,
    required this.cancelToken,
    required this.subscription,
    required this.userMessageId,
    required this.previousAguiState,
    ActiveRunState? initialState,
  }) : state = initialState ?? const IdleState();

  final RunKey key;
  String get roomId => key.roomId;
  String get threadId => key.threadId;
  final String runId;
  final CancelToken cancelToken;
  final StreamSubscription<BaseEvent> subscription;
  final String userMessageId;
  final Map<String, dynamic> previousAguiState;
  ActiveRunState state;
  bool get isActive => state.isRunning;

  Future<void> dispose() async {
    // Idempotent — safe to call multiple times.
    cancelToken.cancel();
    await subscription.cancel();
  }
}
```

### Tests

- Unit: RunHandle holds all resources
- Unit: isActive reflects state (running vs idle vs completed)
- Unit: dispose() cancels token and subscription
- Unit: dispose() is idempotent (safe to call multiple times)
- Unit: key has value equality for same roomId/threadId
- Unit: convenience getters forward to key

### Acceptance Criteria

- [ ] RunHandle class created with all fields
- [ ] dispose() properly cleans up resources
- [ ] All tests pass

---

## Slice 3: RunRegistry Class

**Branch:** `feat/network-multiplexer/03-registry`

**Target:** ~120 lines

**Customer value:** Internal refactor. Centralizes run management logic,
enabling multiple concurrent runs.

### Tasks

1. Create `lib/core/services/run_registry.dart`
2. Define `RunRegistry` class with `Map<RunKey, RunHandle>`
3. Implement `registerRun()`, `getRunState()`, `getHandle()`, `hasRun()`,
   `hasActiveRun()`, `removeRun()`, `removeAll()`
4. Add unit tests

### Files Created

- `lib/core/services/run_registry.dart`
- `test/core/services/run_registry_test.dart`

### RunRegistry API

```dart
class RunRegistry {
  final Map<RunKey, RunHandle> _runs = {};

  /// Register a run handle (replaces existing for same key).
  Future<void> registerRun(RunHandle handle);

  /// Get current state for a thread's run, or null if none.
  ActiveRunState? getRunState(RunKey key);

  /// Get the run handle for a thread, or null if none.
  RunHandle? getHandle(RunKey key);

  /// Whether any run (active or completed) is registered for the key.
  bool hasRun(RunKey key);

  /// Whether an actively running (not yet completed) run exists for the key.
  bool hasActiveRun(RunKey key);

  /// Remove a run and dispose its resources.
  Future<void> removeRun(RunKey key);

  /// Dispose all runs.
  Future<void> removeAll();

  int get runCount;
  int get activeRunCount;
  Iterable<RunHandle> get handles;

  Future<void> dispose();
}
```

### Tests

- Unit: registerRun adds handle to registry
- Unit: registerRun replaces existing handle for same key
- Unit: getRunState returns null for unknown thread
- Unit: getRunState returns state for registered thread
- Unit: getHandle returns handle or null
- Unit: hasRun / hasActiveRun return correct values
- Unit: removeRun disposes handle and removes from map
- Unit: removeAll disposes all handles
- Unit: runCount and activeRunCount reflect map state
- Unit: composite key isolates same threadId across rooms

### Acceptance Criteria

- [ ] RunRegistry class created
- [ ] registerRun adds handles to the map
- [ ] Basic CRUD operations work
- [ ] All tests pass

---

## Slice 4: Migrate startRun to Registry

**Branch:** `feat/network-multiplexer/04-migrate-startrun`

**Target:** ~100 lines

**Customer value:** Same user behavior, but run management is now in a dedicated
class. Foundation for all future slices.

### Tasks

1. Embed `RunRegistry` as a field in `ActiveRunNotifier` (no separate provider)
2. Expose `registry` getter for testing and lifecycle event access
3. Modify `ActiveRunNotifier.startRun()` to create `RunHandle` and register it
4. Wire up event processing callbacks scoped to each handle via closure
5. Update tests to verify registration works

### Files Modified

- `lib/core/providers/active_run_notifier.dart` (embed registry, refactor
  startRun)
- Tests

### Implementation Notes

The registry is embedded directly in the notifier (`final RunRegistry _registry
= RunRegistry()`) rather than exposed as a separate provider. This keeps the
provider footprint minimal (per issue #127). The notifier's `startRun()` creates
the RunHandle and registers it. Each run's stream subscription callbacks capture
their own `RunHandle` via closure, so concurrent runs don't interfere.

### Acceptance Criteria

- [ ] `startRun()` creates RunHandle and registers with registry
- [ ] `ActiveRunNotifier` uses registry for tracking
- [ ] All existing behavior preserved
- [ ] All tests pass

---

## Slice 5: Multi-Thread Concurrent Runs

**Branch:** `feat/network-multiplexer/05-concurrent`

**Target:** ~80 lines

**Customer value:** User can ask questions in multiple threads without waiting.
Each thread has its own streaming response.

### Tasks

1. Remove single-run restriction in `ActiveRunNotifier`
2. Add test: "can start runs in different threads"
3. Add test: "both runs stream independently"

### Files Modified

- `lib/core/providers/active_run_notifier.dart`
- Tests

### Tests

- Integration: Start run in thread A, then start run in thread B
- Integration: Both runs stream independently
- Integration: Cancelling one run doesn't affect the other

### Acceptance Criteria

- [ ] Multiple threads can have active runs simultaneously
- [ ] Each run streams independently
- [ ] All tests pass

---

## Slice 6: Thread-Aware UI Subscription

**Branch:** `feat/network-multiplexer/06-ui-subscription`

**Target:** ~80 lines

**Customer value:** Switching threads shows the correct run state. Returning to
a thread shows its progress instantly.

### Tasks

1. When thread selection changes, subscribe notifier to that thread's run
2. Expose that run's state as the notifier's state
3. Handle case where thread has no active run (IdleState)
4. Add tests for subscription switching

### Files Modified

- `lib/core/providers/active_run_notifier.dart`
- Tests

### Implementation

```dart
ref
  ..listen(currentRoomIdProvider, (_, __) => _syncCurrentHandle())
  ..listen(currentThreadIdProvider, (_, __) => _syncCurrentHandle());

void _syncCurrentHandle() {
  final roomId = ref.read(currentRoomIdProvider);
  final threadId = ref.read(currentThreadIdProvider);
  if (roomId == null || threadId == null) {
    _currentHandle = null;
    state = const IdleState();
    return;
  }
  final key = (roomId: roomId, threadId: threadId);
  _currentHandle = _registry.getHandle(key);
  state = _currentHandle?.state ?? const IdleState();
}
```

### Tests

- Widget: Switching from thread A to B shows B's run state
- Widget: Switching to thread with no run shows IdleState
- Widget: Returning to thread shows preserved state

### Acceptance Criteria

- [ ] UI shows correct run state when switching threads
- [ ] Thread with no run shows IdleState
- [ ] Smooth transition between threads
- [ ] All tests pass

---

## Slice 7: Lifecycle Events Broadcast

**Branch:** `feat/network-multiplexer/07-lifecycle`

**Target:** ~80 lines

**Customer value:** UI can be notified when a backgrounded run finishes.
Foundation for unread indicators (slice 9).

### Tasks

1. Create `lib/core/models/run_lifecycle_event.dart` with sealed event types
2. Add `Stream<RunLifecycleEvent>` to RunRegistry
3. Add `completeRun()` to RunRegistry for atomic state + event emission
4. Wire `ActiveRunNotifier` terminal transitions through `completeRun()`
5. Add tests for event stream

### Files Created

- `lib/core/models/run_lifecycle_event.dart`

### Files Modified

- `lib/core/services/run_registry.dart` (add lifecycle stream and
  `completeRun()`)
- `lib/core/providers/active_run_notifier.dart` (delegate terminal transitions
  to `completeRun()`)
- `test/core/services/run_registry_test.dart` (lifecycle event tests)
- `test/core/providers/active_run_notifier_test.dart`

### Event Definitions

```dart
@immutable
sealed class RunLifecycleEvent {
  const RunLifecycleEvent({required this.key});
  final RunKey key;
  String get roomId => key.roomId;
  String get threadId => key.threadId;
}

@immutable
class RunStarted extends RunLifecycleEvent {
  const RunStarted({required super.key});
}

@immutable
class RunCompleted extends RunLifecycleEvent {
  const RunCompleted({required super.key, required this.result});
  final CompletionResult result;  // Success, FailedResult, or CancelledResult
}
```

### Design Decisions

**Two event types, not three.** The original spec had `RunStarted`,
`RunCompleted`, and `RunErrored`. A run that errors has completed — the
outcome is already encoded in the `CompletionResult` sealed hierarchy
(`Success`, `FailedResult`). A separate `RunErrored` would duplicate that
information and force every consumer to handle two event types identically
in the common case (both slices 8 and 9 react to "run ended" regardless
of outcome).

**`completeRun()` for atomic transitions.** Without this method, every
call site would need to both set `handle.state` and emit the event —
forgetting the emission would be a silent bug. `completeRun()` makes the
right thing easy and the wrong thing hard.

**Unconditional emission.** The registry emits `RunCompleted` for all
terminal results including `CancelledResult`. Consumers filter as needed.
This keeps the registry a faithful event bus rather than embedding business
policy about which events are "interesting." If a future consumer (e.g.,
analytics) needs cancellation events, they're available on the stream.

**`RunKey` typedef with convenience getters.** A named record typedef
`({String roomId, String threadId})` provides a type-safe composite
identifier with value equality. Used as the map key in RunRegistry (no
string concatenation, no `_makeKey()` helper), the identity field in
RunHandle and RunLifecycleEvent. Convenience getters on both types expose
`roomId` and `threadId` directly, so consumers write `event.roomId`
without `.key` indirection.

### ActiveRunNotifier Integration

Four terminal transition sites in `ActiveRunNotifier` delegate to
`_registry.completeRun(handle, completed)` instead of setting
`handle.state` directly:

1. `cancelRun()` — user-initiated cancel
2. `_processEventForRun()` — `RunFinishedEvent` from stream
3. `_handleFailureForRun()` — stream error
4. `_handleDoneForRun()` — stream closes normally

Non-terminal transitions (e.g., `RunningState` with updated messages)
still set `handle.state` directly — no event needs to fire for
intermediate updates.

### Tests

- Unit: RunStarted emitted when registerRun is called
- Unit: RunCompleted emitted for Success
- Unit: RunCompleted emitted for FailedResult
- Unit: RunCompleted emitted for CancelledResult
- Unit: completeRun sets handle state
- Unit: stream closed on dispose
- Integration: stream completion emits RunCompleted via registry
- Integration: stream error emits RunCompleted with FailedResult
- Integration: cancelRun emits RunCompleted with CancelledResult
- Integration: RunFinishedEvent emits RunCompleted via registry

### Acceptance Criteria

- [ ] Lifecycle events stream exposed on RunRegistry
- [ ] `completeRun()` atomically sets state and emits event
- [ ] Events emitted for all terminal transitions (success, failure, cancel)
- [ ] All tests pass

---

## Slice 8: Background Cache Updates

**Branch:** `feat/network-multiplexer/08-cache`

**Target:** ~60 lines

**Customer value:** User returns to a thread and sees all messages, even if they
navigated away during streaming.

### Tasks

1. When run completes (in registry), update ThreadMessageCache
2. Handle both success and error completions
3. Add tests for cache updates from background runs

### Files Modified

- `lib/core/services/run_registry.dart`
- `lib/core/providers/thread_message_cache.dart` (if needed)
- Tests

### Implementation

Currently, `_updateCacheOnCompletion` is called in `ActiveRunNotifier`. This
logic needs to move to (or be triggered by) the registry so it works for
background runs.

### Tests

- Integration: Run completes while viewing different thread, cache updated
- Integration: Return to thread, messages are all present
- Unit: Cache update called on RunCompleted

### Acceptance Criteria

- [ ] Background run completion updates cache
- [ ] User sees all messages when returning
- [ ] All tests pass

---

## Slice 9: Unread Run Indicators

**Branch:** `feat/network-multiplexer/09-unread-indicators`

**Target:** ~120 lines

**Customer value:** User sees visual feedback when background runs complete.
Blue dot on threads, count badge on rooms.

### Tasks

1. Create `UnreadRunsNotifier` to track threads with unread completed runs
2. Listen to lifecycle events and mark threads as unread on `RunCompleted`
3. Add blue dot with glow to thread list items for unread threads
4. Add count badge (white on blue) to room cards for unread thread count
5. Clear unread status when user views the thread

### Files Created

- `lib/core/providers/unread_runs_provider.dart`
- `test/core/providers/unread_runs_provider_test.dart`

### Files Modified

- `lib/features/history/widgets/thread_list_item.dart` (add blue dot)
- `lib/features/rooms/widgets/room_card.dart` (add count badge)
- Tests

### UnreadRunsNotifier API

```dart
class UnreadRunsNotifier extends Notifier<Map<String, Set<String>>> {
  // Map<roomId, Set<threadId>> of threads with unread completed runs

  /// Mark a thread as having an unread completed run.
  void markUnread(String roomId, String threadId);

  /// Mark a thread as read (user viewed it).
  void markRead(String roomId, String threadId);

  /// Check if a thread has unread completed runs.
  bool hasUnread(String roomId, String threadId);

  /// Get count of unread threads in a room.
  int unreadCountForRoom(String roomId);
}
```

### UI Components

**Thread dot (history sidebar):**

- Blue dot with subtle glow effect
- Positioned to the right of thread title
- Disappears when thread is selected

**Room badge (room listing):**

- Count of threads with unread runs
- White text on blue background (same blue as thread dot)
- Only shown when count > 0

### Tests

- Unit: markUnread adds thread to set
- Unit: markRead removes thread from set
- Unit: hasUnread returns correct value
- Unit: unreadCountForRoom returns correct count
- Widget: Thread list item shows blue dot when unread
- Widget: Room card shows count badge when unread threads exist

### Acceptance Criteria

- [ ] Blue dot with glow shown on threads with unread completed runs
- [ ] Count badge shown on rooms with unread threads
- [ ] Unread status cleared when user views thread
- [ ] All tests pass

---

## Slice 10: Cross-Room Composite Key

**Branch:** `feat/network-multiplexer/10-composite-key`

**Target:** ~50 lines

**Customer value:** Prepares for cross-room persistence. Avoids threadId
collisions if backend generates same IDs per room.

**Note:** The `RunKey` typedef and `Map<RunKey, RunHandle>` were introduced
in slices 2–3, so the core keying infrastructure already exists. This slice
audits remaining code paths that may still use threadId alone without roomId
context.

### Tasks

1. Audit all code paths for threadId-only lookups (without roomId context)
2. Verify `_syncCurrentHandle()` constructs a proper `RunKey` with both IDs
3. Add cross-room integration tests if not already covered

### Files Modified

- Any code using threadId-only lookups
- Tests

### Tests

- Unit: Same threadId in different rooms are distinct runs (already in
  `run_registry_test.dart`)
- Integration: Run in room A thread X, run in room B thread X, both tracked

### Acceptance Criteria

- [ ] No code paths use threadId alone where roomId is also needed
- [ ] No collisions across rooms
- [ ] All tests pass

---

## Slice 11: Remove Room-Switch Cancellation

**Branch:** `feat/network-multiplexer/11-room-switch`

**Target:** ~40 lines

**Customer value:** User can switch rooms while AI is responding. Return to
original room and response is still there.

### Tasks

1. Verify no room-change listeners cancel runs
2. Add tests for room switching with active runs
3. Update any UI that assumes single-room context

### Files Modified

- `lib/core/providers/active_run_notifier.dart` (verify no room listeners)
- `lib/core/providers/rooms_provider.dart` (verify no cancellation)
- Tests

### Tests

- Integration: Run in room A, switch to room B, return to A, run continues
- Integration: Run in room A, start run in room B, both active

### Acceptance Criteria

- [ ] Runs persist across room navigation
- [ ] Multiple rooms can have active runs
- [ ] All tests pass

---

## Branch Naming Convention

| Slice | Branch |
|-------|--------|
| 1 | `feat/network-multiplexer/01-skeleton` |
| 2 | `feat/network-multiplexer/02-run-handle` |
| 3 | `feat/network-multiplexer/03-registry` |
| 4 | `feat/network-multiplexer/04-migrate-startrun` |
| 5 | `feat/network-multiplexer/05-concurrent` |
| 6 | `feat/network-multiplexer/06-ui-subscription` |
| 7 | `feat/network-multiplexer/07-lifecycle` |
| 8 | `feat/network-multiplexer/08-cache` |
| 9 | `feat/network-multiplexer/09-unread-indicators` |
| 10 | `feat/network-multiplexer/10-composite-key` |
| 11 | `feat/network-multiplexer/11-room-switch` |

## Critical Files

**Modified:**

- `lib/core/providers/active_run_notifier.dart` - Remove listener (slice 1),
  embed registry and delegate run tracking (slice 4), sync current handle on
  navigation (slice 6)
- `lib/core/providers/thread_message_cache.dart` - Update on background
  completion (slice 8)

**Created:**

- `lib/core/models/run_handle.dart` - RunKey typedef + RunHandle class (slice 2)
- `lib/core/services/run_registry.dart` - RunRegistry class (slice 3)
- `lib/core/models/run_lifecycle_event.dart` - Lifecycle events (slice 7)

## Definition of Done (per slice)

- [ ] All tasks completed
- [ ] All tests written and passing
- [ ] Code formatted (`mcp__dart__dart_format`)
- [ ] No analyzer issues (`mcp__dart__analyze_files`)
- [ ] Coverage >= 85%
- [ ] PR reviewed and approved
- [ ] Merged to `main`

## Verification Checklist (end state)

1. Navigate away from thread with active run - run continues
2. Navigate back - see streamed messages
3. Start runs in multiple threads - all tracked correctly
4. Background run completes - cache updated, lifecycle event broadcast
5. Navigate between rooms - runs persist
