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
| 9 | Cross-room composite key | ~50 | Runs keyed by (roomId, threadId) |
| 10 | Remove room-switch cancellation | ~40 | Full navigation independence |

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
    ▼              ▼
[6] UI sub   [8] Cache updates
    │
    ▼
[9] Cross-room key
    │
    ▼
[10] Room-switch
```

**Parallel from slice 4:** Slices 5-6 (multi-run path) and 7-8 (events path) can
proceed in parallel after slice 4 merges.

## Implementation Order

1. **Slice 1** - Walking skeleton (required first, immediate value)
2. **Slice 2** - RunHandle model
3. **Slice 3** - RunRegistry class
4. **Slice 4** - Migrate startRun (architecture complete)
5. **Slice 5** - Multi-thread concurrent runs (parallel with 7)
6. **Slice 7** - Lifecycle events (parallel with 5)
7. **Slice 6** - Thread-aware UI subscription
8. **Slice 8** - Background cache updates
9. **Slice 9** - Cross-room composite key
10. **Slice 10** - Remove room-switch cancellation

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
2. Define `RunHandle` class with: roomId, threadId, cancelToken, subscription,
   state
3. Move dispose logic from `RunningInternalState` to `RunHandle`
4. Add unit tests for `RunHandle`

### Files Created

- `lib/core/models/run_handle.dart`
- `test/core/models/run_handle_test.dart`

### RunHandle API

```dart
class RunHandle {
  RunHandle({
    required this.roomId,
    required this.threadId,
    required this.cancelToken,
    required this.subscription,
    this.state = const IdleState(),
  });

  final String roomId;
  final String threadId;
  final CancelToken cancelToken;
  final StreamSubscription<BaseEvent> subscription;
  ActiveRunState state;

  String get key => '$roomId:$threadId';

  Future<void> dispose() async {
    cancelToken.cancel();
    await subscription.cancel();
  }
}
```

### Tests

- Unit: RunHandle holds all resources
- Unit: dispose() cancels token and subscription
- Unit: key property returns correct composite key

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
2. Define `RunRegistry` class with Map<String, RunHandle>
3. Implement `getRunState()`, `hasActiveRun()`, `cancelRun()`
4. Implement `maxConcurrentRuns` limit check
5. Add unit tests

### Files Created

- `lib/core/services/run_registry.dart`
- `test/core/services/run_registry_test.dart`

### RunRegistry API (partial - startRun in slice 4)

```dart
class RunRegistry {
  RunRegistry({this.maxConcurrentRuns = 5});

  final int maxConcurrentRuns;
  final Map<String, RunHandle> _runs = {};

  /// Get current state for a thread's run, or null if none.
  ActiveRunState? getRunState(String roomId, String threadId);

  /// Check if a run is active for the given thread.
  bool hasActiveRun(String roomId, String threadId);

  /// Cancel a specific run.
  Future<void> cancelRun(String roomId, String threadId);

  /// Cancel all runs.
  Future<void> cancelAll();

  /// Number of active runs.
  int get activeRunCount;

  void dispose();
}
```

### Tests

- Unit: getRunState returns null for unknown thread
- Unit: hasActiveRun returns false for unknown thread
- Unit: cancelRun disposes handle and removes from map
- Unit: cancelAll disposes all handles
- Unit: activeRunCount reflects map size

### Acceptance Criteria

- [ ] RunRegistry class created
- [ ] Basic CRUD operations work
- [ ] All tests pass

---

## Slice 4: Migrate startRun to Registry

**Branch:** `feat/network-multiplexer/04-migrate-startrun`

**Target:** ~100 lines

**Customer value:** Same user behavior, but run management is now in a dedicated
class. Foundation for all future slices.

### Tasks

1. Create `lib/core/providers/run_registry_provider.dart`
2. Add `startRun()` method to `RunRegistry`
3. Modify `ActiveRunNotifier.startRun()` to delegate to registry
4. Wire up event processing to update RunHandle state
5. Update tests to verify delegation works

### Files Created

- `lib/core/providers/run_registry_provider.dart`

### Files Modified

- `lib/core/services/run_registry.dart` (add startRun)
- `lib/core/providers/active_run_notifier.dart` (delegate to registry)
- Tests for both

### Implementation Notes

The registry's `startRun()` needs access to:

- `AgUiClient` for streaming
- `SoliplexApi` for creating runs
- `ThreadMessageCache` for reading cached messages

Options:

1. Pass these as parameters to `startRun()`
2. Inject via constructor
3. Pass a callback/factory for stream setup

Recommend option 1 for simplicity - the notifier already has access to these
via ref.

### Acceptance Criteria

- [ ] `startRun()` creates RunHandle and adds to registry
- [ ] `ActiveRunNotifier` delegates to registry
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
2. Modify registry to allow multiple concurrent runs (up to limit)
3. Add test: "can start runs in different threads"
4. Add test: "max concurrent runs enforced"

### Files Modified

- `lib/core/providers/active_run_notifier.dart`
- `lib/core/services/run_registry.dart`
- Tests

### Tests

- Integration: Start run in thread A, then start run in thread B
- Integration: Both runs stream independently
- Unit: Registry enforces maxConcurrentRuns
- Unit: Attempt to exceed limit throws/returns error

### Acceptance Criteria

- [ ] Multiple threads can have active runs simultaneously
- [ ] Each run streams independently
- [ ] Max concurrent runs limit is enforced
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
ref.listen(threadSelectionProvider, (previous, next) {
  if (next is ThreadSelected) {
    final roomId = ref.read(currentRoomIdProvider);
    if (roomId != null) {
      _subscribeToThread(roomId, next.threadId);
    }
  }
});

void _subscribeToThread(String roomId, String threadId) {
  final registry = ref.read(runRegistryProvider);
  state = registry.getRunState(roomId, threadId) ?? const IdleState();
  // Subscribe to state changes for this thread...
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
Foundation for badges/toasts/alerts (design TBD).

### Tasks

1. Add `Stream<RunLifecycleEvent>` to RunRegistry
2. Define `RunStarted`, `RunCompleted`, `RunErrored` events
3. Broadcast events when run state changes
4. Add tests for event stream

### Files Modified

- `lib/core/services/run_registry.dart`
- Tests

### Event Definitions

```dart
sealed class RunLifecycleEvent {
  String get roomId;
  String get threadId;
}

class RunStarted extends RunLifecycleEvent {
  RunStarted({required this.roomId, required this.threadId});
  @override final String roomId;
  @override final String threadId;
}

class RunCompleted extends RunLifecycleEvent {
  RunCompleted({
    required this.roomId,
    required this.threadId,
    required this.result,
  });
  @override final String roomId;
  @override final String threadId;
  final CompletionResult result;
}

class RunErrored extends RunLifecycleEvent {
  RunErrored({
    required this.roomId,
    required this.threadId,
    required this.errorMessage,
  });
  @override final String roomId;
  @override final String threadId;
  final String errorMessage;
}
```

### Tests

- Unit: RunStarted emitted when run starts
- Unit: RunCompleted emitted when run finishes
- Unit: RunErrored emitted when run fails
- Unit: Events include correct roomId and threadId

### Acceptance Criteria

- [ ] Lifecycle events stream exposed
- [ ] Events emitted at correct times
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

## Slice 9: Cross-Room Composite Key

**Branch:** `feat/network-multiplexer/09-composite-key`

**Target:** ~50 lines

**Customer value:** Prepares for cross-room persistence. Avoids threadId
collisions if backend generates same IDs per room.

### Tasks

1. Ensure all registry operations use `(roomId, threadId)` tuple as key
2. Update any code that uses threadId alone
3. Add tests for cross-room scenarios

### Files Modified

- `lib/core/services/run_registry.dart` (verify key usage)
- Any code using threadId-only lookups
- Tests

### Tests

- Unit: Same threadId in different rooms are distinct runs
- Integration: Run in room A thread X, run in room B thread X, both tracked

### Acceptance Criteria

- [ ] Runs keyed by (roomId, threadId)
- [ ] No collisions across rooms
- [ ] All tests pass

---

## Slice 10: Remove Room-Switch Cancellation

**Branch:** `feat/network-multiplexer/10-room-switch`

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
| 9 | `feat/network-multiplexer/09-composite-key` |
| 10 | `feat/network-multiplexer/10-room-switch` |

## Critical Files

**Modified:**

- `lib/core/providers/active_run_notifier.dart` - Remove listener (slice 1),
  delegate to registry (slice 4), subscribe to current thread (slice 6)
- `lib/core/providers/thread_message_cache.dart` - Update on background
  completion (slice 8)

**Created:**

- `lib/core/models/run_handle.dart` - RunHandle class (slice 2)
- `lib/core/services/run_registry.dart` - RunRegistry class (slice 3)
- `lib/core/providers/run_registry_provider.dart` - Provider (slice 4)

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
