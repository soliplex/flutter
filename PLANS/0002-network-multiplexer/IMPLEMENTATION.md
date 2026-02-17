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
| 10 | Cross-room composite key | ~200 | Cache + registry keyed by (roomId, threadId) |
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

- [x] Run continues when user navigates away from thread
- [x] Run state is preserved when user returns
- [x] All existing tests pass (or are updated appropriately)
- [x] No memory leaks (run resources are still cleaned up on completion)

---

## Slice 2: RunHandle Model

**Branch:** `feat/network-multiplexer/02-run-handle`

**Target:** ~60 lines

**Customer value:** Internal refactor. Encapsulates run resources for cleaner
code and prepares for multi-run tracking.

### Tasks

1. Create `lib/core/models/run_handle.dart`
2. Define `RunHandle` class with: key (ThreadKey), runId, cancelToken,
   subscription, userMessageId, previousAguiState, state, isActive
3. Move dispose logic from `RunningInternalState` to `RunHandle` (idempotent)
4. Add unit tests for `RunHandle`

### Files Created

- `lib/core/models/thread_key.dart`
- `lib/core/models/run_handle.dart`
- `test/core/models/run_handle_test.dart`

### RunHandle API

```dart
// ThreadKey is defined in lib/core/models/thread_key.dart

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

  final ThreadKey key;
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

- [x] RunHandle class created with all fields
- [x] dispose() properly cleans up resources
- [x] All tests pass

---

## Slice 3: RunRegistry Class

**Branch:** `feat/network-multiplexer/03-registry`

**Target:** ~120 lines

**Customer value:** Internal refactor. Centralizes run management logic,
enabling multiple concurrent runs.

### Tasks

1. Create `lib/core/services/run_registry.dart`
2. Define `RunRegistry` class with `Map<ThreadKey, RunHandle>`
3. Implement `registerRun()`, `getRunState()`, `getHandle()`, `hasRun()`,
   `hasActiveRun()`, `removeRun()`, `removeAll()`
4. Add unit tests

### Files Created

- `lib/core/services/run_registry.dart`
- `test/core/services/run_registry_test.dart`

### RunRegistry API

```dart
typedef OnRunCompleted = void Function(ThreadKey key, CompletedState completed);

class RunRegistry {
  RunRegistry({this.onRunCompleted});

  final OnRunCompleted? onRunCompleted;
  final Map<ThreadKey, RunHandle> _runs = {};

  Stream<RunLifecycleEvent> get lifecycleEvents;

  Future<void> registerRun(RunHandle handle);
  void completeRun(RunHandle handle, CompletedState completed);
  void notifyCompletion(ThreadKey key, CompletedState completed);

  /// Get current state for a thread's run, or null if none.
  ActiveRunState? getRunState(ThreadKey key);

  /// Get the run handle for a thread, or null if none.
  RunHandle? getHandle(ThreadKey key);

  /// Whether any run (active or completed) is registered for the key.
  bool hasRun(ThreadKey key);

  /// Whether an actively running (not yet completed) run exists for the key.
  bool hasActiveRun(ThreadKey key);

  /// Remove a run and dispose its resources.
  Future<void> removeRun(ThreadKey key);

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

- [x] RunRegistry class created
- [x] registerRun adds handles to the map
- [x] Basic CRUD operations work
- [x] All tests pass

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

The registry is owned by `ActiveRunNotifier` as a `late final` field,
created with the `OnRunCompleted` callback via constructor injection.
This avoids Riverpod provider proliferation (per issue #127) while
keeping the registry independently testable. The notifier's `startRun()`
creates the RunHandle and registers it. Each run's stream subscription
callbacks capture their own `RunHandle` via closure, so concurrent runs
don't interfere.

### Acceptance Criteria

- [x] `startRun()` creates RunHandle and registers with registry
- [x] `ActiveRunNotifier` uses registry for tracking
- [x] All existing behavior preserved
- [x] All tests pass

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

- [x] Multiple threads can have active runs simultaneously
- [x] Each run streams independently
- [x] All tests pass

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

- [x] UI shows correct run state when switching threads
- [x] Thread with no run shows IdleState
- [x] Smooth transition between threads
- [x] All tests pass

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
  final ThreadKey key;
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

**`ThreadKey` typedef with convenience getters.** A named record typedef
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

- [x] Lifecycle events stream exposed on RunRegistry
- [x] `completeRun()` atomically sets state and emits event
- [x] Events emitted for all terminal transitions (success, failure, cancel)
- [x] All tests pass

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

- `lib/core/services/run_registry.dart` — `OnRunCompleted` callback typedef
- `lib/core/providers/active_run_notifier.dart` — `_buildCacheUpdater()`
  passed via `RunRegistry` constructor
- `lib/core/providers/thread_history_cache.dart`
- Tests

### Implementation

Cache updates are passed to `RunRegistry` via constructor injection of the
`OnRunCompleted` callback. `ActiveRunNotifier._buildCacheUpdater()` returns
a closure that merges completed run messages and messageStates into
`ThreadHistoryCache`. The registry invokes this callback from
`completeRun()` and `notifyCompletion()`, so background runs update the
cache without needing the notifier to be in the foreground.

### Tests

- Integration: Run completes while viewing different thread, cache updated
- Integration: Return to thread, messages are all present
- Unit: Cache update called on RunCompleted

### Acceptance Criteria

- [x] Background run completion updates cache
- [x] User sees all messages when returning
- [x] All tests pass

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
- `lib/features/rooms/widgets/room_grid_card.dart` (add count badge)
- Tests

### UnreadRuns / UnreadRunsNotifier API

```dart
class UnreadRuns {
  const UnreadRuns({Map<String, Set<String>> byRoom = const {}});

  bool isThreadUnread(ThreadKey key);
  int unreadCountForRoom(String roomId);
  bool get isEmpty;
}

class UnreadRunsNotifier extends Notifier<UnreadRuns> {
  void markUnread(ThreadKey key);
  void markRead(ThreadKey key);
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
- Unit: isThreadUnread returns correct value
- Unit: unreadCountForRoom returns correct count
- Widget: Thread list item shows blue dot when unread
- Widget: Room grid card shows count badge when unread threads exist

### Acceptance Criteria

- [x] Blue dot with glow shown on threads with unread completed runs
- [x] Count badge shown on rooms with unread threads
- [x] Unread status cleared when user views thread
- [x] All tests pass

---

## Slice 10: Cross-Room Composite Key

**Branch:** `refact/active-run-notifier-responsibility-scope`

**Target:** ~200 lines (actual, across 12 files)

**Customer value:** Eliminates cross-room cache collisions. All data layers
use composite `ThreadKey` consistently.

**Note:** The `ThreadKey` typedef and `Map<ThreadKey, RunHandle>` were introduced
in slices 2–3, so the core keying infrastructure already exists. This slice
audits remaining code paths that may still use threadId alone without roomId
context.

### Tasks

1. Audit all code paths for threadId-only lookups (without roomId context)
2. Verify `_syncCurrentHandle()` constructs a proper `ThreadKey` with both IDs
3. Add cross-room integration tests if not already covered

### Files Modified

- `lib/core/providers/thread_history_cache.dart` — re-keyed state and APIs
- `lib/core/services/run_registry.dart` — `OnRunCompleted` and
  `notifyCompletion` accept `ThreadKey`
- `lib/core/providers/active_run_notifier.dart` — cache lookups, callback,
  `notifyCompletion` calls
- `lib/core/providers/active_run_provider.dart` — composite key cache lookup
- `lib/core/providers/source_references_provider.dart` — added
  `currentRoomIdProvider` watch, composite key
- `lib/features/chat/chat_panel.dart` — added `room.id` to `updateHistory`
- `test/core/providers/thread_history_cache_test.dart` — all tests + cross-room
- `test/core/providers/active_run_notifier_test.dart` — cache key assertions
- `test/core/providers/active_run_provider_test.dart` — test helpers + assertions
- `test/core/providers/source_references_provider_test.dart` — room override +
  `updateHistory` calls
- `test/core/services/run_registry_test.dart` — callback signatures
- `test/features/chat/chat_panel_test.dart` — cache assertion

### Tests

- Unit: Same threadId in different rooms produces separate cache entries
- Unit: All existing cache tests updated to use composite keys
- Integration: `OnRunCompleted` callback receives `ThreadKey`

### Acceptance Criteria

- [x] `ThreadHistoryCache` keyed by `ThreadKey` instead of `String`
- [x] All consumers use composite keys for cache access
- [x] `OnRunCompleted` and `notifyCompletion` pass `ThreadKey`
- [x] Cross-room test proves no cache collision
- [x] All 1326 tests pass

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

- [x] Runs persist across room navigation
- [x] Multiple rooms can have active runs
- [x] All tests pass

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
  own registry field (slice 4), sync current handle on navigation
  (slice 6), pass cache-update callback via constructor (slice 8), subscribe to lifecycle
  events for unread indicators (slice 9)
- `lib/core/providers/thread_history_cache.dart` - Re-keyed from
  `Map<String, ThreadHistory>` to `Map<ThreadKey, ThreadHistory>` (slice 10)
- `lib/core/providers/active_run_provider.dart` - Composite key cache
  lookup (slice 10)
- `lib/core/providers/source_references_provider.dart` - Composite key cache
  lookup with roomId watch (slice 10)
- `lib/features/chat/chat_panel.dart` - roomId in updateHistory (slice 10)

**Created:**

- `lib/core/models/thread_key.dart` - ThreadKey typedef (slice 2)
- `lib/core/models/run_handle.dart` - RunHandle class (slice 2)
- `lib/core/services/run_registry.dart` - RunRegistry class (slice 3)
- `lib/core/models/run_lifecycle_event.dart` - Lifecycle events (slice 7)
- `lib/core/providers/unread_runs_provider.dart` - Unread indicators (slice 9)

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
