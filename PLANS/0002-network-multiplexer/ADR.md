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

  Future<void> dispose() async { ... }  // Idempotent
}
```

**Rationale:** The existing `RunningInternalState` already bundles these
resources. Extracting to a standalone class enables multi-run tracking and
improves testability.

#### 2. RunKey Record Typedef

Runs are identified by `typedef RunKey = ({String roomId, String threadId})`,
a named record providing type-safe composite identity with value equality.
`RunKey` is used as the map key in `RunRegistry`, the identity field in
`RunHandle` and `RunLifecycleEvent`. Convenience getters on both types
expose `roomId` and `threadId` directly.

**Rationale:**

- Thread IDs may not be globally unique across rooms (depends on backend)
- Record value equality eliminates string-concatenation keys and `_makeKey()`
- Type-safe map key: `Map<RunKey, RunHandle>` vs `Map<String, RunHandle>`
- Registry API takes one param (`RunKey`) instead of two strings
- Event construction is terser: `RunStarted(key: handle.key)`
- Convenience getters preserve consumer ergonomics: `event.roomId`

#### 3. Minimal Provider Footprint

Expose `RunRegistry` via a single provider (or integrate into
`activeRunNotifierProvider`). Domain logic stays in the `RunRegistry` class.

**Rationale:** Per issue #127, avoid proliferating providers. Centralized logic
is easier to test and reason about.

#### 4. Two Lifecycle Event Types (not three)

The registry broadcasts `Stream<RunLifecycleEvent>` with:

- `RunStarted` — emitted when a run is registered
- `RunCompleted` — emitted for all terminal transitions (success, failure,
  cancellation)

The original spec had a separate `RunErrored` type, but a run that errors
*has completed*. The outcome is encoded in the existing `CompletionResult`
sealed hierarchy (`Success`, `FailedResult`, `CancelledResult`), which
already provides exhaustive pattern matching. A separate `RunErrored` would
duplicate this information and force consumers to handle two event types
identically — both slices 8 (cache) and 9 (unread indicators) react to
"run ended" regardless of outcome.

**Rationale:** Separation of concerns. The registry doesn't know or care about
UI. The UI can evolve its presentation independently.

#### 5. Atomic Completion via `completeRun()`

Terminal state transitions go through `RunRegistry.completeRun(handle,
completed)` rather than setting `handle.state` directly. This method
atomically sets the handle's state and emits the lifecycle event.

**Rationale:** Without this, every call site would need to both set the
state and emit the event. Forgetting the emission would be a silent bug.
`completeRun()` makes the right thing easy and the wrong thing hard.

#### 6. Unconditional Event Emission

The registry emits `RunCompleted` for all terminal results including
`CancelledResult`. Consumers decide which results to act on.

**Rationale:** The registry is infrastructure — a faithful event bus that
reports what happened. Filtering is a business policy decision that belongs
in consumers. If a future consumer needs cancellation events (e.g.,
analytics), they're available on the stream without modifying the registry.

#### 7. Incremental Migration

The implementation is divided into 11 slices. Slice 1 (walking skeleton)
delivers immediate value by simply removing the cancel-on-navigate behavior.
Subsequent slices refactor toward the full registry pattern.

**Rationale:** Users benefit from slice 1 immediately. If priorities change,
the basic improvement is already shipped.

### Components

#### RunHandle

```dart
typedef RunKey = ({String roomId, String threadId});

/// Encapsulates resources for a single active run.
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

#### RunRegistry

```dart
/// Manages multiple concurrent AG-UI runs.
class RunRegistry {
  final Map<RunKey, RunHandle> _runs = {};
  final _controller = StreamController<RunLifecycleEvent>.broadcast();

  Stream<RunLifecycleEvent> get lifecycleEvents => _controller.stream;

  /// Register a run handle (replaces existing for same key). Emits RunStarted.
  Future<void> registerRun(RunHandle handle) async { ... }

  /// Atomically set terminal state and emit RunCompleted.
  /// Silently returns if disposed or handle was replaced by a newer run.
  void completeRun(RunHandle handle, CompletedState completed) { ... }

  /// Get current state for a thread's run, or null if none.
  ActiveRunState? getRunState(RunKey key) { ... }

  /// Get the run handle for a thread, or null if none.
  RunHandle? getHandle(RunKey key) { ... }

  /// Whether any run (active or completed) is registered for the key.
  bool hasRun(RunKey key) { ... }

  /// Whether an actively running (not yet completed) run exists for the key.
  bool hasActiveRun(RunKey key) { ... }

  /// Remove a run and dispose its resources (no lifecycle event).
  Future<void> removeRun(RunKey key) async { ... }

  /// Dispose all runs without emitting lifecycle events.
  Future<void> removeAll() async { ... }

  int get runCount;
  int get activeRunCount;
  Iterable<RunHandle> get handles;

  Future<void> dispose() async {
    await removeAll();
    await _controller.close();
  }
}
```

#### RunLifecycleEvent

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

### Provider Integration

The registry is embedded in `ActiveRunNotifier` rather than exposed as a
separate provider. This keeps the provider footprint minimal (per issue #127)
and makes the registry an implementation detail of the notifier. A `registry`
getter provides external access for testing and lifecycle event consumption.

```dart
class ActiveRunNotifier extends Notifier<ActiveRunState> {
  final RunRegistry _registry = RunRegistry();

  /// The run whose state the notifier exposes to UI.
  RunHandle? _currentHandle;

  /// Exposed for testing and external access to run tracking state.
  RunRegistry get registry => _registry;

  @override
  ActiveRunState build() {
    // Sync exposed state when the user navigates between rooms/threads.
    ref
      ..listen(currentRoomIdProvider, (_, __) => _syncCurrentHandle())
      ..listen(currentThreadIdProvider, (_, __) => _syncCurrentHandle())
      ..onDispose(() => _registry.dispose());

    return const IdleState();
  }

  Future<void> startRun({...}) async {
    // Creates RunHandle, registers with _registry, subscribes to events.
    // Each run's stream callbacks capture their own handle via closure
    // so concurrent runs don't interfere with each other.
  }

  void _syncCurrentHandle() {
    // Looks up the run for the current room/thread in the registry
    // and updates _currentHandle + notifier state accordingly.
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
