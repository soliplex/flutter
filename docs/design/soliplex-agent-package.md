# soliplex_agent — Pure Dart Orchestration Package

## Purpose

Extract agent orchestration logic from the Flutter app into a pure Dart
package that depends only on `soliplex_client` (and `soliplex_logging`).
This creates a testable, framework-agnostic layer between the protocol
(soliplex_client) and the UI (Flutter app).

## Dependency Constraint

```text
soliplex_agent
  ├── soliplex_client   (domain models, API types, AG-UI, ToolRegistry)
  ├── soliplex_logging   (Logger type for structured logging)
  └── meta               (annotations)

NOT allowed:
  - flutter SDK
  - flutter_riverpod
  - shared_preferences
  - Any Flutter app package
```

This constraint is enforced by `pubspec.yaml` having no Flutter dependency
and by `analysis_options.yaml` inheriting `very_good_analysis`.

## What soliplex_client Already Provides

`soliplex_agent` does not duplicate anything from `soliplex_client`. It
consumes these types:

| Category | Types |
|----------|-------|
| **Domain** | `RunInfo`, `ThreadHistory`, `ThreadInfo`, `Conversation`, `ChatMessage`, `MessageState`, `Room`, `RoomAgent`, `SourceReference` |
| **AG-UI** | `BaseEvent`, `RunStartedEvent`, `RunFinishedEvent`, `RunErrorEvent`, `ToolCallStartEvent`, `ToolCallResultEvent`, `TextMessageContentEvent`, `StepStartedEvent`, `StepFinishedEvent`, `SimpleRunAgentInput`, `Tool`, `ToolCallInfo` |
| **Application** | `ToolRegistry`, `ClientTool`, `ToolExecutor`, `StreamingState`, `AgUiEventProcessor`, `CitationExtractor` |
| **HTTP** | `CancelToken` |
| **API** | `SoliplexApi` (concrete class — see HostApi discussion below) |

## What Moves into soliplex_agent

### Models (pure, zero-change moves)

| Current Path | New Path | Dependencies |
|---|---|---|
| `lib/core/models/thread_key.dart` | `src/models/thread_key.dart` | None (typedef) |
| `lib/core/models/active_run_state.dart` | `src/run/run_state.dart` | `soliplex_client` (Conversation, ChatMessage, ToolCallInfo, StreamingState), `meta` |
| `lib/core/models/run_handle.dart` | `src/run/run_handle.dart` | `dart:async`, `soliplex_client`, run_state, thread_key |
| `lib/core/models/run_lifecycle_event.dart` | `src/run/run_lifecycle_event.dart` | `meta`, run_state, thread_key |

All four files are pure Dart with zero Flutter imports. They move as-is
with only import path changes.

### Services (pure, minor changes)

| Current Path | New Path | Dependencies | Change Needed |
|---|---|---|---|
| `lib/core/services/run_registry.dart` | `src/run/run_registry.dart` | `dart:async`, run_state, run_handle, run_lifecycle_event, thread_key | Replace `Loggers.activeRun` with injected `Logger` |
| M1: `run_preparator.dart` | `src/services/run_preparator.dart` | `soliplex_client` (Conversation, Running) | None — already pure |
| M1: `agui_event_logger.dart` | `src/services/agui_event_logger.dart` | `soliplex_client` (BaseEvent subtypes) | Replace `Loggers.activeRun` with injected `Logger` |
| M1: `run_completion_handler.dart` | `src/services/run_completion_handler.dart` | `soliplex_client` (ChatMessage, SourceReference, ThreadHistory) | Replace `Loggers.activeRun` with injected `Logger` |

The logging change is mechanical: replace `Loggers.activeRun.info(...)` with
a `Logger` parameter passed via constructor or function argument.

### New Code

| File | Role |
|---|---|
| `src/host/host_api.dart` | Abstract interface — GUI + native platform boundary |
| `src/host/platform_constraints.dart` | Platform constraint flags (parallel, async, concurrency) |
| `src/run/run_orchestrator.dart` | Core orchestration (Phase 2 — extracted from ActiveRunNotifier) |
| `src/cache/thread_history_cache.dart` | Framework-agnostic cache (Phase 3) |

## What Stays in the Flutter App

| File | Reason |
|---|---|
| `providers/active_run_notifier.dart` | Riverpod notifier — thin wrapper after Phase 2 |
| `providers/active_run_provider.dart` | Derived Riverpod providers |
| `providers/api_provider.dart` | HTTP stack wiring, provider graph |
| `providers/rooms_provider.dart` | Riverpod + Room state |
| `providers/threads_provider.dart` | Riverpod + SharedPreferences |
| `providers/thread_history_cache.dart` | Riverpod notifier (until Phase 3 extraction) |
| `providers/unread_runs_provider.dart` | Riverpod + Set state |
| All `features/` widgets | UI layer |
| `services/thread_bridge_cache.dart` | Monty bridge wiring (Riverpod + platform factory) |
| `services/monty_platform_factory*.dart` | Platform-specific code |

## Dependency Injection: Direct vs Interface

### What Gets Injected Directly

`SoliplexApi`, `AgUiClient`, and `PlatformConstraints` are already pure
Dart. They're constructed by the Flutter app (which owns auth, base URLs,
platform HTTP adapters) but once constructed, they're plain objects.
`soliplex_agent` takes them as constructor parameters — no wrapping
interface needed.

```dart
class RunOrchestrator {
  RunOrchestrator({
    required SoliplexApi api,
    required AgUiClient agUiClient,
    required ToolRegistry toolRegistry,
    required PlatformConstraints platform,
    required Logger logger,
  });
}
```

`SoliplexApi` provides: `createRun()`, `createThread()`, `getRoom()`,
`getThreadHistory()` — all the backend access the orchestrator needs.

`AgUiClient` provides: `runAgent()` — the AG-UI event stream.

`ToolRegistry` provides: `execute()` — client-side tool execution.
Note: tool registries are room-scoped because different rooms have
different backend tool definitions. The Flutter app constructs the
right registry per room. Some tool executors may capture Riverpod
`ref` internally (e.g., a tool that shows a confirmation dialog),
but that's opaque to the orchestrator — it just calls `execute()`.

### What Needs an Interface: HostApi

The only operations that need an abstract interface are those where
Python / the agent runtime needs to reach across to the GUI:

```dart
/// Interface for operations that cross the platform boundary.
///
/// Two categories of things the pure Dart runtime cannot do:
/// 1. Render Flutter widgets (DataFrames, charts)
/// 2. Access native platform APIs (location, camera, file picker,
///    clipboard, biometrics) that require OS permissions or hardware
///
/// The Flutter app implements this. Tests mock it.
abstract interface class HostApi {
  // ── Visual rendering ─────────────────────────────────────────────

  /// Register a DataFrame for display in the host UI.
  int registerDataFrame(Map<String, List<Object?>> columns);

  /// Retrieve a registered DataFrame by handle.
  Map<String, List<Object?>>? getDataFrame(int handle);

  /// Register a chart configuration for rendering.
  int registerChart(Map<String, Object?> chartConfig);

  // ── Platform services + extensibility ────────────────────────────

  /// Invoke a host operation by namespaced name.
  ///
  /// Covers both platform services (location, camera, file picker)
  /// and extensible host functions (future GUI operations).
  /// The host handles permission requests, hardware access, and OS
  /// dialogs. Returns the result or throws on denial/unavailability.
  ///
  /// Naming convention:
  ///   'native.location'     → GPS coordinates
  ///   'native.clipboard'    → clipboard read/write
  ///   'native.file_picker'  → file picker dialog
  ///   'ui.show_dialog'      → Flutter dialog
  ///   'ui.navigate'         → GoRouter navigation
  Future<Object?> invoke(String name, Map<String, Object?> args);
}
```

This is the platform boundary — the *only* reason an interface exists.
Everything else is direct injection of pure Dart objects.

The platform boundary covers two concerns:

- **GUI:** Pure Dart can't import Flutter or render widgets
- **Native:** Pure Dart can't access OS permissions, hardware, or
  platform-specific APIs (location, camera, clipboard, biometrics)

### Design Rationale

Why not wrap `SoliplexApi` behind an interface?

- **It's already pure Dart** — `soliplex_client` is a pure Dart package.
  Wrapping it adds indirection with no benefit.
- **Testability is unchanged** — mock `SoliplexApi` directly with
  `mocktail`. Same effort as mocking a `HostApi` method.
- **No UX leak** — API calls don't touch the GUI. They return data.
  The Flutter layer observes orchestrator state via streams and decides
  how to present it.

Why DO we need `HostApi`?

- **GUI operations can't be pure Dart** — `registerDataFrame()` must
  eventually produce a Flutter `DataTable` widget. The runtime stores
  the data; Flutter renders it. That crossing requires an interface.
- **Tool executors may touch GUI** — some `ToolRegistry` executors
  capture Riverpod `ref` to show dialogs, navigate, etc. The registry
  is constructed by Flutter with those closures baked in. The
  orchestrator calls `execute()` without knowing what's inside.
- **Python calls GUI host functions** — `df_create()`, `chart_line()`,
  `invoke()` — these are the Monty bridge's channel to
  Flutter widgets. Pure Dart can't render.

### Notification Model: Observe, Don't Push

There are no callback methods like `onRunCompleted` or
`updateCachedHistory`. The orchestrator doesn't push state to the host.

Instead, the orchestrator exposes state via streams:

```dart
class RunOrchestrator {
  Stream<RunState> get stateChanges;   // Flutter subscribes
  RunState get currentState;            // Flutter reads
}

class AgentRuntime {
  Stream<List<AgentSession>> get sessionChanges;  // Flutter subscribes
  AgentSession? getSession(ThreadKey key);         // Flutter reads
}
```

The Flutter layer subscribes and reacts:

```dart
// In ActiveRunNotifier (thin Riverpod wrapper)
_orchestrator.stateChanges.listen((s) {
  state = s;  // Update Riverpod → triggers UI rebuild

  if (s is CompletedState) {
    // Flutter-layer decisions:
    ref.read(unreadRunsProvider.notifier).markUnread(key);
    ref.read(threadHistoryCacheProvider.notifier).update(key, ...);
  }
});
```

This keeps the orchestrator unaware of Riverpod, caching, unread
markers, or any other UX concern.

### PlatformConstraints

Separate from `HostApi` because platform constraints are global
(per app instance), not per session:

```dart
/// Platform-level capability flags.
///
/// Allows agent orchestration and the Monty bridge to adapt behavior
/// based on runtime constraints.
abstract interface class PlatformConstraints {
  /// Whether the platform supports parallel Python interpreters.
  ///
  /// Native (Isolate): true. Web (WASM singleton): false.
  bool get supportsParallelExecution;

  /// Whether the Monty runtime supports async/futures mode.
  ///
  /// WASM: false (sync-only start/resume loop).
  /// Native: false today, potentially true when MontyResolveFutures lands.
  bool get supportsAsyncMode;

  /// Max concurrent Monty bridges before serialization is required.
  ///
  /// Native: high (one Isolate each). Web: 1 (mutex-serialized).
  int get maxConcurrentBridges;

  /// Whether the interpreter can be re-entered while suspended.
  ///
  /// Native (Isolate): true — each bridge has its own interpreter.
  /// Web (WASM): false — single interpreter, non-reentrant.
  /// Used by AgentRuntime to guard against WASM deadlocks when a
  /// sub-agent's tool call would require Python execution while
  /// Python is already suspended on wait_all().
  bool get supportsReentrantInterpreter;
}
```

## RunOrchestrator (Phase 2)

The big extraction. Takes the ~750 lines of pure orchestration logic out of
`ActiveRunNotifier` and puts it behind `HostApi`.

### What It Does

1. **Start a run:** prepare input, create run on backend, start event
   stream, register in RunRegistry
2. **Process events:** delegate to AgUiEventProcessor (already in
   soliplex_client), log events, map results to state transitions
3. **Tool execution loop:** detect pending tools, execute via
   ToolRegistry, continue stream (recursive with depth limit)
4. **Complete a run:** correlate citations, build updated history, notify
   host for cache update and unread markers
5. **Cancel a run:** cancel token, clean up subscription, transition state
6. **Thread sync:** when user navigates to a different thread, swap the
   active run handle

### Interface

```dart
class RunOrchestrator {
  RunOrchestrator({
    required SoliplexApi api,
    required AgUiClient agUiClient,
    required ToolRegistry toolRegistry,
    required PlatformConstraints platformConstraints,
    required Logger logger,
  });

  /// The current run state (idle, running, executing tools, completed).
  RunState get currentState;

  /// Stream of state changes for external observation.
  Stream<RunState> get stateChanges;

  /// Start a new run or continue an existing one.
  ///
  /// [key] identifies the thread.
  /// [userMessage] is the user's input text.
  /// [existingRunId] resumes a run (for tool continuation).
  /// [cachedHistory] avoids a fetch if the host already has it.
  Future<void> startRun({
    required ThreadKey key,
    required String userMessage,
    String? existingRunId,
    ThreadHistory? cachedHistory,
  });

  /// Cancel the active run.
  Future<void> cancelRun();

  /// Reset to idle state.
  Future<void> reset();

  /// Sync to a different thread (user navigated away).
  void syncToThread(ThreadKey? key);

  /// Release resources.
  Future<void> dispose();
}
```

### How It Uses HostApi

Every external operation goes through the host:

```dart
// Direct API calls — no interface wrapper
final runInfo = await _api.createRun(key.roomId, key.threadId);

// Direct AG-UI streaming
final stream = _agUiClient.runAgent(
  runInfo.endpoint,
  preparedInput,
  cancelToken: cancelToken,
);

// Direct history fetch
final history = cachedHistory ??
    await _api.getThreadHistory(key.roomId, key.threadId);

// Tool execution via injected registry
final result = await _toolRegistry.execute(toolCall);

// State transitions — just update internal state.
// Flutter observes via stateChanges stream and reacts.
_setState(CompletedState(result: success));
```

No callbacks, no notifications. The orchestrator changes its own state.
The Flutter layer watches `stateChanges` and handles cache updates,
unread markers, and any other UX side effects.

### What Changes in ActiveRunNotifier (After Phase 2)

The notifier shrinks to ~80-100 lines:

```dart
class ActiveRunNotifier extends Notifier<RunState> {
  late RunOrchestrator _orchestrator;

  @override
  RunState build() {
    _orchestrator = RunOrchestrator(
      api: ref.watch(apiProvider),
      agUiClient: ref.watch(agUiClientProvider),
      toolRegistry: ref.watch(toolRegistryProvider),
      platformConstraints: ref.watch(platformConstraintsProvider),
      logger: Loggers.activeRun,
    );

    // Observe orchestrator state → update Riverpod state + side effects
    _orchestrator.stateChanges.listen((s) {
      state = s;

      // Flutter-layer reactions (cache, unread, etc.)
      if (s is CompletedState) {
        final key = _orchestrator.registry.currentKey;
        if (key != null) {
          ref.read(unreadRunsProvider.notifier).markUnread(key);
          ref.read(threadHistoryCacheProvider.notifier)
              .update(key, s.toHistory());
        }
      }
    });

    // Sync when user navigates to different room/thread
    ref
      ..listen(currentRoomIdProvider, (_, id) => _sync())
      ..listen(currentThreadIdProvider, (_, id) => _sync())
      ..onDispose(() => _orchestrator.dispose());

    return const IdleState();
  }

  Future<void> startRun({...}) => _orchestrator.startRun(...);
  Future<void> cancelRun() => _orchestrator.cancelRun();
  Future<void> reset() => _orchestrator.reset();

  void _sync() {
    final roomId = ref.read(currentRoomIdProvider);
    final threadId = ref.read(currentThreadIdProvider);
    if (roomId != null && threadId != null) {
      _orchestrator.syncToThread((roomId: roomId, threadId: threadId));
    } else {
      _orchestrator.syncToThread(null);
    }
  }
}
```

No `_FlutterHostApi` class needed. The Riverpod providers
supply the pure Dart objects directly. The notifier itself handles the
UX side effects (unread markers, cache updates) in its stream listener.

## AgentRuntime (Phase 4+)

The multi-session coordination layer. Manages concurrent agent sessions
spawned by Python scripts via Monty host functions (`spawn_agent`,
`wait_all`, etc.).

### ToolRegistryResolver

Different rooms have different backend tool definitions and potentially
different Flutter UI tool cards. The runtime resolves the right registry
per room at spawn time:

```dart
/// Resolves a room-scoped ToolRegistry.
///
/// Flutter implements this by reading room tool definitions, merging with
/// client-side tools, and returning a ToolRegistry with executor closures
/// that may capture Riverpod ref internally (opaque to the runtime).
typedef ToolRegistryResolver =
    Future<ToolRegistry> Function(String roomId);
```

### Interface

```dart
/// Manages concurrent agent sessions.
///
/// Lives in soliplex_agent. Pure Dart, no Flutter.
/// Each spawned session gets its own RunOrchestrator with a room-scoped
/// ToolRegistry resolved via the injected resolver.
class AgentRuntime {
  AgentRuntime({
    required SoliplexApi api,
    required AgUiClient agUiClient,
    required ToolRegistryResolver toolRegistryResolver,
    required PlatformConstraints platform,
    required Logger logger,
    String serverId = 'default',
  });

  /// Spawn a new agent session. Returns a handle for coordination.
  ///
  /// The runtime resolves the ToolRegistry for [roomId] via the
  /// injected resolver, creates a RunOrchestrator, and starts the run.
  Future<AgentSession> spawn({
    required String roomId,
    required String prompt,
    String? threadId,        // Auto-create if null
    Duration? timeout,
    bool ephemeral = false,  // Auto-delete thread on completion
  });

  /// Wait for all sessions to complete.
  Future<List<AgentResult>> waitAll(
    List<AgentSession> sessions, {
    Duration? timeout,
  });

  /// Wait for the first session to complete.
  Future<AgentResult> waitAny(
    List<AgentSession> sessions, {
    Duration? timeout,
  });

  /// Get an active session by thread key, if one exists.
  AgentSession? getSession(ThreadKey key);

  /// All currently active sessions (for UI indicators).
  List<AgentSession> get activeSessions;

  /// Stream that emits when sessions are added/removed.
  Stream<List<AgentSession>> get sessionChanges;

  /// Cancel all active sessions.
  Future<void> cancelAll();

  /// Release resources. Cleans up ephemeral threads.
  Future<void> dispose();
}
```

### AgentSession

```dart
/// Handle for a spawned agent session.
class AgentSession {
  /// Unique session identifier.
  String get id;

  /// The thread this session is running in.
  ThreadKey get threadKey;

  /// Current state of the session.
  AgentSessionState get state;

  /// Whether this session's thread is auto-deleted on completion.
  bool get ephemeral;

  /// Completes when the session reaches a terminal state.
  Future<AgentResult> get result;

  /// Waits for the session result with an optional timeout.
  Future<AgentResult> awaitResult({Duration? timeout});

  /// Cancel this session. No-op if already terminal.
  void cancel();
}
```

### AgentResult

```dart
/// Result of a completed agent session.
sealed class AgentResult {
  const AgentResult({required this.threadKey});
  final ThreadKey threadKey;
}

class AgentSuccess extends AgentResult {
  final String output;
  final String runId;
}

class AgentFailure extends AgentResult {
  final FailureReason reason;
  final String error;
  final String? partialOutput;
}

class AgentTimedOut extends AgentResult {
  final Duration elapsed;
}
```

### Error Handling Contract

The `RunOrchestrator` must handle every failure mode that can occur
during an AG-UI SSE stream. Errors are **data, not exceptions** at the
Dart layer. The sealed `AgentResult` type forces the caller to handle
all terminal states exhaustively.

#### Failure Classification

Every error the orchestrator encounters is classified into one of these
categories, which determines the response:

```dart
/// Why a run failed. Attached to AgentFailure.
enum FailureReason {
  /// Server returned an error event in the AG-UI stream.
  serverError,

  /// Auth token expired or was rejected (401/403).
  authExpired,

  /// Network lost — SSE stream ended without a terminal event.
  networkLost,

  /// Server returned 429 Too Many Requests.
  rateLimited,

  /// Tool execution failed (all retries exhausted).
  toolExecutionFailed,

  /// Internal error in the orchestrator itself.
  internalError,

  /// Run was cancelled by the caller.
  cancelled,
}
```

`AgentFailure` carries this classification:

```dart
class AgentFailure extends AgentResult {
  final FailureReason reason;
  final String error;
  final String? partialOutput;
  final ThreadKey threadKey;
}
```

#### Scenario: Auth Token Expiry (401/403)

**Problem:** The SSE stream or a tool-continuation HTTP request returns
401/403. The bearer token has expired mid-run.

**Contract:**

1. `RunOrchestrator` catches `AuthException` from the stream or HTTP
   call.
2. Transitions to `AgentFailure(reason: FailureReason.authExpired)`.
3. Preserves `partialOutput` from any messages received before the
   error.
4. Does NOT attempt token refresh — that is the Flutter app's
   responsibility.
5. The Flutter layer (provider/notifier) observes `authExpired` and
   redirects to login.

**Rationale:** `soliplex_agent` is pure Dart with no auth state. Token
refresh requires `SharedPreferences`, secure storage, and UI navigation
— all Flutter concerns. The orchestrator's job is to classify the error
and preserve partial work.

#### Scenario: Network Loss Mid-Stream

**Problem:** WiFi drops, cellular switches, or the server crashes. The
SSE stream's `onDone` fires without a `RunSuccessEvent` or error event.

**Contract:**

1. `RunOrchestrator` tracks whether a terminal event (`RunFinished`,
   `RunFailed`) was received before `onDone`.
2. If `onDone` fires WITHOUT a terminal event:
   - Transition to `AgentFailure(reason: FailureReason.networkLost)`.
   - Preserve `partialOutput` from messages received so far.
   - Do NOT treat this as success.
3. If `onDone` fires AFTER a terminal event: normal completion.

**This is the most dangerous gap in the existing app** — today,
`onDone` without a terminal event is silently treated as success.

#### Scenario: SSE Reconnect Strategy

**Problem:** Transient network interruption kills the SSE stream. Should
the orchestrator reconnect?

**Contract:**

1. `RunOrchestrator` does NOT reconnect automatically.
2. Stream end = run end. This is intentional.
3. The AG-UI protocol does not support resuming an SSE stream mid-run.
   A new `startRun` with the existing `runId` would need server support
   for continuation, which is not currently available.
4. The Flutter layer may offer a "Retry" action in the UI when it sees
   `FailureReason.networkLost`.

**Rationale:** Automatic reconnect with retry is complex, error-prone,
and can cause duplicate tool executions. The safer path is: fail fast,
preserve partial output, let the user decide. If the backend adds
stream resumption support later, the orchestrator can add reconnect
as an opt-in behavior gated by `PlatformConstraints`.

**Future consideration:** If `PlatformConstraints` gains a
`supportsStreamResumption` flag, the orchestrator could attempt one
reconnect with an `If-None-Match` or `Last-Event-ID` header before
failing.

#### Scenario: Rate Limiting (429)

**Problem:** Server returns 429 Too Many Requests on the initial SSE
connection or on a tool-continuation request.

**Contract:**

1. `RunOrchestrator` catches the 429 response.
2. Reads the `Retry-After` header if present.
3. Transitions to `AgentFailure(reason: FailureReason.rateLimited)`.
4. Includes the `Retry-After` duration in the error message.
5. Does NOT retry automatically — the Flutter layer can schedule a
   retry with backoff if desired.

#### Scenario: Auth Header Injection

**Problem:** Who puts the bearer token on the SSE request?

**Contract:**

1. `SoliplexApi` is constructed by the Flutter app with an
   `HttpTransport` that has auth headers pre-configured.
2. `RunOrchestrator` receives `SoliplexApi` via constructor injection.
3. The orchestrator never touches auth headers — it calls
   `api.startRun()` and trusts that the transport layer handles auth.
4. If the token needs refreshing, the Flutter app's `AuthNotifier`
   updates the transport's headers. The orchestrator is unaware.

This wiring is the Flutter app's responsibility, not `soliplex_agent`'s.

#### Error Propagation to Callers

The sealed `AgentResult` forces exhaustive handling:

```dart
final result = await session.result;
switch (result) {
  case AgentSuccess(:final output):
    // Use output
  case AgentFailure(:final reason, :final error, :final partialOutput):
    switch (reason) {
      case FailureReason.authExpired:
        // Redirect to login, show partial output if available
      case FailureReason.networkLost:
        // Show "connection lost" with retry action
      case FailureReason.rateLimited:
        // Show "please wait" with retry-after countdown
      case FailureReason.cancelled:
        // User cancelled — acknowledge
      case FailureReason.serverError:
      case FailureReason.toolExecutionFailed:
      case FailureReason.internalError:
        // Show error message, offer retry
    }
  case AgentTimedOut(:final elapsed):
    // Decide: retry with longer timeout, or fail
}
```

At the Python layer, errors become exceptions (idiomatic Python).
The Monty bridge translates between the two models — Dart sealed types
↔ Python exceptions. No automatic propagation — the script IS the
supervisor.

#### What the Orchestrator Does NOT Do

- **No token refresh.** Pure Dart, no auth state.
- **No automatic retry.** Caller decides retry policy.
- **No automatic reconnect.** Stream end = run end.
- **No UI navigation.** Reports `FailureReason`, never pops a dialog.
- **No logging to backend.** Uses injected `Logger` for local logs only.

## ThreadHistoryCache (Phase 3)

Framework-agnostic in-memory LRU cache with deduplication.

```dart
class ThreadHistoryCache {
  ThreadHistoryCache({
    required HostApi host,
    int maxSize = 50,
  });

  /// Current cache state (observable via stream).
  Map<ThreadKey, ThreadHistory> get state;

  /// Stream of cache mutations.
  Stream<Map<ThreadKey, ThreadHistory>> get changes;

  /// Get history, fetching from host if not cached.
  Future<ThreadHistory> getOrFetch(ThreadKey key);

  /// Update cached history directly (e.g., after run completion).
  void update(ThreadKey key, ThreadHistory history);

  /// Invalidate a cache entry.
  void invalidate(ThreadKey key);

  /// Release resources.
  void dispose();
}
```

The Riverpod notifier becomes a thin wrapper:

```dart
class ThreadHistoryCacheNotifier extends Notifier<Map<ThreadKey, ThreadHistory>> {
  late ThreadHistoryCache _cache;

  @override
  Map<ThreadKey, ThreadHistory> build() {
    final host = _FlutterHostApi(ref);
    _cache = ThreadHistoryCache(host: host);
    _cache.changes.listen((s) => state = s);
    ref.onDispose(_cache.dispose);
    return {};
  }

  // Delegate all methods to _cache
}
```

## Package Structure

```text
packages/soliplex_agent/
├── pubspec.yaml
├── analysis_options.yaml
├── lib/
│   ├── soliplex_agent.dart              # Barrel export
│   └── src/
│       ├── host/
│       │   ├── host_api.dart                    # GUI + native platform boundary
│       │   ├── platform_constraints.dart        # Platform constraint flags
│       │   ├── fake_host_api.dart               # In-memory HostApi for testing
│       │   ├── native_platform_constraints.dart # Native (Isolate) constraints
│       │   └── web_platform_constraints.dart    # Web (WASM) constraints
│       ├── models/
│       │   ├── thread_key.dart                 # ThreadKey typedef
│       │   ├── agent_result.dart               # Sealed result types
│       │   └── failure_reason.dart             # FailureReason enum
│       ├── run/
│       │   ├── run_state.dart                  # Sealed state hierarchy
│       │   ├── run_orchestrator.dart           # Core orchestration (Phase 2)
│       │   └── error_classifier.dart           # Maps errors to FailureReason
│       ├── runtime/
│       │   ├── agent_runtime.dart             # Multi-session coordinator (Phase 4+)
│       │   ├── agent_session.dart             # Session handle
│       │   └── agent_session_state.dart       # AgentSessionState enum
│       └── tools/
│           └── tool_registry_resolver.dart    # Room-scoped registry factory
└── test/
    ├── host/
    │   └── host_api_test.dart
    ├── run/
    │   ├── run_state_test.dart
    │   └── run_orchestrator_test.dart
    ├── runtime/
    │   ├── agent_runtime_test.dart
    │   └── agent_session_test.dart
    └── tools/
        └── tool_registry_resolver_test.dart
```

## pubspec.yaml

```yaml
name: soliplex_agent
description: Pure Dart orchestration layer for Soliplex agent sessions.
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.6.0

dependencies:
  soliplex_client:
    path: ../soliplex_client
  soliplex_logging:
    path: ../soliplex_logging
  meta: ^1.9.0

dev_dependencies:
  mocktail: ^1.0.0
  test: ^1.24.0
  very_good_analysis: ^10.0.0
```

## Logger Injection Pattern

Files that currently use `Loggers.activeRun` (the app's static accessor)
need to accept a `Logger` parameter instead:

```dart
// Before (in app):
void logAguiEvent(BaseEvent event) {
  Loggers.activeRun.info('...');
}

// After (in soliplex_agent):
void logAguiEvent(BaseEvent event, {required Logger logger}) {
  logger.info('...');
}
```

For classes:

```dart
// Before:
class RunRegistry {
  // Uses Loggers.activeRun directly
}

// After:
class RunRegistry {
  RunRegistry({required Logger logger}) : _logger = logger;
  final Logger _logger;
}
```

The Flutter app passes `Loggers.activeRun` at construction time.

## Import Rewrite Strategy

When files move, every import in the Flutter app that referenced the old
path must update. The pattern is mechanical:

```dart
// Before:
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/models/thread_key.dart';
import 'package:soliplex_frontend/core/services/run_registry.dart';

// After:
import 'package:soliplex_agent/soliplex_agent.dart';
```

Or, for fine-grained imports:

```dart
import 'package:soliplex_agent/src/run/run_state.dart';
import 'package:soliplex_agent/src/models/thread_key.dart';
```

**Recommendation:** Use the barrel export (`soliplex_agent.dart`) for all
external consumers. Keep `src/` imports for internal package use only.

## Implementation Phases

### Phase 1: Skeleton + Pure Moves

Create package, move 4 models + RunRegistry + 3 M1 services. Define
HostApi and PlatformConstraints interfaces. Update all imports in
Flutter app. Add `soliplex_agent` dependency to app pubspec.

**Gate:** `dart format . && flutter analyze --fatal-infos && flutter test`
and `cd packages/soliplex_agent && dart test`

**Risk:** Low — these are import-path-only changes for existing pure code.

### Phase 2: RunOrchestrator Extraction

Create `RunOrchestrator` by extracting logic from `ActiveRunNotifier`.
Create `_FlutterHostApi` in the app. Shrink notifier to thin
wrapper.

**Gate:** Same + notifier < 100 lines + all existing behavior preserved.

**Risk:** Medium — the notifier has complex async state (deferred message
queue, tool execution zones, depth limiting). Must be careful to preserve
all edge cases.

### Phase 3: ThreadHistoryCache Extraction

Create framework-agnostic `ThreadHistoryCache`. Thin wrapper for Riverpod.

**Gate:** Same.

**Risk:** Low — the cache logic is simple (Map + fetch dedup).

### Phase 4: AgentRuntime + Multi-Session

Create `AgentRuntime`, `AgentSession`, `AgentResult`, and
`ToolRegistryResolver`. Wire Monty host functions (`spawn_agent`,
`wait_all`) to the runtime.

**Gate:** Same + spawn/wait_all integration test with mock backend.

**Risk:** Medium-high — concurrent session management, WASM deadlock
guards, ephemeral thread cleanup. Requires Phase 2 (RunOrchestrator)
to be stable first.

### Phase 5: Monty Bridge Alignment (separate workstream)

See `docs/design/monty-host-capabilities-integration.md`.

## Testing Strategy

### In soliplex_agent (pure Dart tests)

```dart
class MockSoliplexApi extends Mock implements SoliplexApi {}
class MockAgUiClient extends Mock implements AgUiClient {}
class MockToolRegistry extends Mock implements ToolRegistry {}

test('RunOrchestrator starts a run', () async {
  final api = MockSoliplexApi();
  final agUiClient = MockAgUiClient();
  final toolRegistry = MockToolRegistry();

  when(() => api.createRun(any(), any()))
      .thenAnswer((_) async => RunInfo(id: 'run-1', endpoint: '/run'));
  when(() => agUiClient.runAgent(any(), any()))
      .thenAnswer((_) => Stream.fromIterable([
        RunStartedEvent(threadId: 't1', runId: 'run-1'),
        RunFinishedEvent(threadId: 't1', runId: 'run-1'),
      ]));

  final orchestrator = RunOrchestrator(
    api: api,
    agUiClient: agUiClient,
    toolRegistry: toolRegistry,
    platformConstraints: FakePlatformConstraints(),
    logger: Logger('test'),
  );

  await orchestrator.startRun(
    key: (serverId: 'default', roomId: 'r1', threadId: 't1'),
    userMessage: 'Hello',
  );

  expect(orchestrator.currentState, isA<CompletedState>());
});
```

### In Flutter app (widget/integration tests)

Existing tests continue to work because `ActiveRunNotifier` exposes the
same public API. Internal delegation to `RunOrchestrator` is transparent.

## Verification Checklist

After each phase:

1. `dart format .` — no changes
2. `flutter analyze --fatal-infos` — 0 issues
3. `flutter test` — all pass
4. `cd packages/soliplex_agent && dart test` — all pass
5. Manual: send message, create thread, cancel run, tool execution
