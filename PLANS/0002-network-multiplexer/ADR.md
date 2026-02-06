# ADR: Network Multiplexer Implementation

## Status

Proposed

## Context

Users lose AI responses when navigating between threads because
`ActiveRunNotifier` cancels runs on thread change. We need to support multiple
concurrent runs that persist across navigation.

See [SPEC.md](./SPEC.md) for requirements and use cases.

**Issue:** <https://github.com/soliplex/flutter/issues/71>

### Current Architecture

```dart
// active_run_notifier.dart lines 90-96
ref.listen(threadSelectionProvider, (previous, next) {
  if (previous is ThreadSelected) {
    unawaited(reset());  // <-- Cancels run when leaving thread
  }
});
```

The notifier manages a single run with these internal states:

- `IdleInternalState`: No active run
- `RunningInternalState`: Holds `CancelToken` + `StreamSubscription`

This design assumes one run at a time, scoped to the current thread.

## Decision

### Approach: Run Registry Pattern

Create a `RunRegistry` service class that:

1. Tracks multiple active runs by `(roomId, threadId)` key
2. Manages run lifecycle (register, cancel, complete)
3. Broadcasts lifecycle events via a stream

The `ActiveRunNotifier` is modified to:

1. Stop cancelling runs on thread navigation (slice 1)
2. Delegate run management to the registry (slice 4)
3. Subscribe to the current thread's run state (slice 6)

### Key Design Decisions

#### 1. RunHandle Encapsulation

Bundle run resources into a `RunHandle` class:

```dart
class RunHandle {
  final String roomId;
  final String threadId;
  final CancelToken cancelToken;
  final StreamSubscription<BaseEvent> subscription;
  ActiveRunState state;

  Future<void> dispose() async {
    cancelToken.cancel();
    await subscription.cancel();
  }
}
```

**Rationale:** The existing `RunningInternalState` already bundles these
resources. Extracting to a standalone class enables multi-run tracking and
improves testability.

#### 2. Composite Key: (roomId, threadId)

Runs are keyed by both room and thread ID, not just thread ID.

**Rationale:**

- Thread IDs may not be globally unique across rooms (depends on backend)
- Future multi-room support requires distinguishing runs in different rooms
- Explicit room context prevents subtle bugs if thread ID collision occurs

#### 3. Minimal Provider Footprint

Expose `RunRegistry` via a single provider (or integrate into
`activeRunNotifierProvider`). Domain logic stays in the `RunRegistry` class.

**Rationale:** Per issue #127, avoid proliferating providers. Centralized logic
is easier to test and reason about.

#### 4. UI-Agnostic Lifecycle Events

The registry broadcasts `Stream<RunLifecycleEvent>` with:

- `RunStarted`
- `RunCompleted`
- `RunErrored`

UI components decide how to present these (toast, badge, dot, etc.).

**Rationale:** Separation of concerns. The registry doesn't know or care about
UI. The UI can evolve its presentation independently.

#### 5. Incremental Migration

The implementation is divided into 10 slices. Slice 1 (walking skeleton)
delivers immediate value by simply removing the cancel-on-navigate behavior.
Subsequent slices refactor toward the full registry pattern.

**Rationale:** Users benefit from slice 1 immediately. If priorities change,
the basic improvement is already shipped.

### Components

#### RunHandle

```dart
/// Encapsulates resources for a single active run.
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

#### RunRegistry

```dart
/// Manages multiple concurrent AG-UI runs.
class RunRegistry {
  final Map<String, RunHandle> _runs = {};
  final _lifecycleController = StreamController<RunLifecycleEvent>.broadcast();

  Stream<RunLifecycleEvent> get lifecycleEvents => _lifecycleController.stream;

  /// Register a run handle in the registry.
  void registerRun(RunHandle handle) { ... }

  /// Get current state for a thread's run, or null if none.
  ActiveRunState? getRunState(String roomId, String threadId) { ... }

  /// Cancel a specific run.
  Future<void> cancelRun(String roomId, String threadId) async { ... }

  /// Cancel all runs (for cleanup).
  Future<void> cancelAll() async { ... }

  void dispose() {
    _lifecycleController.close();
  }
}
```

#### RunLifecycleEvent

```dart
sealed class RunLifecycleEvent {
  String get roomId;
  String get threadId;
}

class RunStarted extends RunLifecycleEvent { ... }

class RunCompleted extends RunLifecycleEvent {
  final CompletionResult result;
}

class RunErrored extends RunLifecycleEvent {
  final String errorMessage;
}
```

### Provider Integration

```dart
/// Single provider for the RunRegistry instance.
final runRegistryProvider = Provider<RunRegistry>((ref) {
  final registry = RunRegistry();
  ref.onDispose(registry.dispose);
  return registry;
});
```

`ActiveRunNotifier` is modified to use the registry:

```dart
class ActiveRunNotifier extends Notifier<ActiveRunState> {
  @override
  ActiveRunState build() {
    final registry = ref.watch(runRegistryProvider);

    // Subscribe to current thread's state changes
    ref.listen(threadSelectionProvider, (previous, next) {
      if (next is ThreadSelected) {
        final roomId = ref.read(currentRoomIdProvider);
        if (roomId != null) {
          _subscribeToRun(roomId, next.threadId);
        }
      }
    });

    return const IdleState();
  }

  Future<void> startRun({...}) async {
    final registry = ref.read(runRegistryProvider);
    await registry.startRun(...);
  }
}
```

## Consequences

### Positive

- Runs survive navigation - users don't lose streaming responses
- Multiple concurrent runs enable productive multi-tasking
- Clean separation: registry manages runs, UI subscribes to what it needs
- Incremental implementation - value delivered in slice 1
- Foundation for future multi-server support (DM7-DM8 roadmap)

### Negative

- More state to manage (multiple runs vs. one)
- Increased memory usage with concurrent runs
- More complex debugging when multiple runs are active

### Risks

- **Race conditions:** Concurrent runs + thread switching creates potential for
  race conditions. Mitigated by careful state management and tests.
- **Cache staleness:** If user modifies messages in a thread while a background
  run is active, cache could become inconsistent. Accepted risk - users
  shouldn't edit while AI is responding.

## Alternatives Considered

### 1. Keep Single-Run Model, Cache State on Navigate

**Approach:** When navigating away, serialize run state to cache. Restore on
return.

**Rejected because:**

- Doesn't support concurrent runs
- Complex serialization of `StreamSubscription` (impossible) and
  `CancelToken` state
- Would need to pause/resume backend streams (backend doesn't support this)

### 2. Move Run Management Entirely to Backend

**Approach:** Backend tracks all active runs per user. Frontend polls for state.

**Rejected because:**

- Requires significant backend changes
- Polling introduces latency vs. SSE streaming
- Doesn't solve the frontend navigation problem

### 3. Use Riverpod Family Providers Per Thread

**Approach:** `activeRunProvider.family((roomId, threadId))` creates separate
provider instances per thread.

**Rejected because:**

- Proliferates providers (violates issue #127 guidance)
- Hard to track all active runs for cleanup
- Lifecycle events would need separate aggregation

## References

- [Issue #71: Runs cancelled on navigation](https://github.com/soliplex/flutter/issues/71)
- [Issue #127: Minimal provider footprint](https://github.com/soliplex/flutter/issues/127)
- [Riverpod State Management](https://riverpod.dev/)
- [AG-UI Protocol Spec](https://docs.ag-ui.com/)
