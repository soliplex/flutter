# Runtime Guide

How `AgentRuntime` coordinates multiple `AgentSession` instances,
enforces platform constraints, and manages thread lifecycle.

## Architecture

```mermaid
graph TD
    subgraph AgentRuntime
        RT["AgentRuntime<br/>spawn / waitAll / waitAny / cancelAll / dispose"]
        SC["sessionChanges<br/>Stream&lt;List&lt;AgentSession&gt;&gt;"]
    end

    subgraph Sessions
        S1["AgentSession A<br/>threadKey: (srv, room-1, thr-1)"]
        S2["AgentSession B<br/>threadKey: (srv, room-2, thr-2)"]
        S3["AgentSession C<br/>threadKey: (srv, room-1, thr-3)"]
    end

    subgraph Orchestrators
        O1["RunOrchestrator A"]
        O2["RunOrchestrator B"]
        O3["RunOrchestrator C"]
    end

    RT --> S1
    RT --> S2
    RT --> S3
    S1 --> O1
    S2 --> O2
    S3 --> O3

    O1 --> API["SoliplexApi"]
    O2 --> API
    O3 --> API
    O1 --> AGUI["AgUiClient"]
    O2 --> AGUI
    O3 --> AGUI

    RT -.-> SC

    style RT fill:#d4edda,stroke:#28a745,stroke-width:2px
    style S1 fill:#bbdefb,stroke:#1565c0
    style S2 fill:#bbdefb,stroke:#1565c0
    style S3 fill:#bbdefb,stroke:#1565c0
    style O1 fill:#ffe0b2,stroke:#e65100
    style O2 fill:#ffe0b2,stroke:#e65100
    style O3 fill:#ffe0b2,stroke:#e65100
```

Each `AgentRuntime` is bound to a single backend via `SoliplexApi`.
The `serverId` (defaults to `'default'`) is embedded into every
`ThreadKey` created by `spawn()`. Multiple servers = multiple runtime
instances.

Each `spawn()` call creates a fresh `RunOrchestrator` and
`AgentSession`. The session auto-executes tools and completes with
an `AgentResult`.

## spawn() flow

```mermaid
sequenceDiagram
    participant Caller
    participant RT as AgentRuntime
    participant API as SoliplexApi
    participant Resolver as ToolRegistryResolver
    participant Session as AgentSession
    participant RO as RunOrchestrator

    Caller->>RT: spawn(roomId, prompt, threadId?, timeout?, ephemeral?)
    RT->>RT: guardNotDisposed()
    RT->>RT: guardWasmReentrancy()
    RT->>RT: guardConcurrency()

    alt threadId provided
        RT->>RT: build ThreadKey directly
    else no threadId
        RT->>API: createThread(roomId)
        API-->>RT: ThreadInfo { id, initialRunId? }
        RT->>RT: build ThreadKey from response
    end

    RT->>Resolver: resolve(roomId)
    Resolver-->>RT: ToolRegistry

    RT->>RT: create RunOrchestrator + AgentSession
    RT->>RT: trackSession (add to map, emit sessionChanges)

    RT->>Session: start(userMessage, existingRunId?)
    Session->>RO: startRun(key, userMessage, existingRunId?)

    RT->>RT: scheduleCompletion(session, timeout)
    RT-->>Caller: AgentSession

    Note over Session,RO: Session auto-executes tools on ToolYieldingState
```

## Concurrency model

```mermaid
flowchart TD
    SPAWN["spawn() called"]
    DISPOSED{"disposed?"}
    WASM{"WASM platform<br/>+ active sessions > 0?"}
    LIMIT{"activeCount >=<br/>maxConcurrentBridges?"}
    OK["proceed with spawn"]
    ERR1["StateError: disposed"]
    ERR2["StateError: WASM<br/>no concurrent sessions"]
    ERR3["StateError: concurrency<br/>limit reached"]

    SPAWN --> DISPOSED
    DISPOSED -->|yes| ERR1
    DISPOSED -->|no| WASM
    WASM -->|yes| ERR2
    WASM -->|no| LIMIT
    LIMIT -->|yes| ERR3
    LIMIT -->|no| OK

    style ERR1 fill:#ffcdd2,stroke:#c62828
    style ERR2 fill:#ffcdd2,stroke:#c62828
    style ERR3 fill:#ffcdd2,stroke:#c62828
    style OK fill:#c8e6c9,stroke:#2e7d32
```

### Platform constraints

| Platform | `supportsReentrantInterpreter` | `maxConcurrentBridges` | Effect |
|----------|-------------------------------|------------------------|--------|
| Native | `true` | `4` (default) | Many concurrent sessions |
| Web (WASM) | `false` | `1` | Single session; WASM guard blocks 2nd spawn |

The WASM guard prevents deadlocks where a sub-agent tool call would
require Python execution while Python is already suspended on
`wait_all()`. Validated in spike testing.

## waitAll / waitAny

```mermaid
sequenceDiagram
    participant Caller
    participant RT as AgentRuntime
    participant S1 as Session A
    participant S2 as Session B
    participant S3 as Session C

    Caller->>RT: spawn() x3
    RT-->>Caller: [S1, S2, S3]

    par waitAll
        Caller->>RT: waitAll([S1, S2, S3], timeout: 30s)
        RT->>S1: awaitResult(timeout: 30s)
        RT->>S2: awaitResult(timeout: 30s)
        RT->>S3: awaitResult(timeout: 30s)
        S1-->>RT: AgentSuccess
        S2-->>RT: AgentFailure
        S3-->>RT: AgentSuccess
        RT-->>Caller: [AgentSuccess, AgentFailure, AgentSuccess]
    end

    Note over Caller,RT: waitAny returns the first result<br/>from Future.any()
```

`waitAll` uses `Future.wait` — all sessions must complete. One failure
does not cancel the others. The caller receives all results and can
inspect each.

`waitAny` uses `Future.any` — returns the first session to complete.
Other sessions continue running (cancel manually if needed).

## Error propagation

```mermaid
flowchart TD
    subgraph "Session-level errors (inside AgentResult)"
        SE["Stream error<br/>(network, auth, rate limit)"]
        TE["Tool depth exceeded"]
        CE["cancelRun()"]
        SE --> FAIL["AgentFailure(reason)"]
        TE --> FAIL
        CE --> CANCEL["AgentFailure(cancelled)"]
    end

    subgraph "Runtime-level errors (thrown from spawn)"
        DE["Runtime disposed"]
        WE["WASM re-entrancy"]
        LE["Concurrency limit"]
        AE["createThread fails<br/>(auth, network)"]
        RE["resolver fails"]
        DE --> STATE["StateError"]
        WE --> STATE
        LE --> STATE
        AE --> THROWN["Exception propagates"]
        RE --> THROWN
    end

    FAIL --> RESULT["Caller reads session.result"]
    CANCEL --> RESULT
    STATE --> CATCH["Caller catches from spawn()"]
    THROWN --> CATCH

    style FAIL fill:#ffcdd2,stroke:#c62828
    style CANCEL fill:#fff9c4,stroke:#f9a825
    style STATE fill:#ffcdd2,stroke:#c62828
    style THROWN fill:#ffcdd2,stroke:#c62828
    style RESULT fill:#bbdefb,stroke:#1565c0
    style CATCH fill:#ffe0b2,stroke:#e65100
```

Two error paths:

1. **Session-level**: Errors during the run (stream errors, tool depth,
   cancel) flow through `AgentResult`. Read via `session.result`.
2. **Runtime-level**: Errors before the run starts (guards, thread
   creation, tool resolution) throw synchronously from `spawn()`.
   The caller catches them directly.

## Ephemeral thread lifecycle

```mermaid
sequenceDiagram
    participant RT as AgentRuntime
    participant API as SoliplexApi
    participant S as AgentSession

    RT->>API: createThread(roomId)
    API-->>RT: ThreadInfo
    RT->>S: start(prompt)

    Note over S: run completes...

    S-->>RT: session complete
    RT->>API: deleteThread(roomId, threadId)
    RT->>RT: removeSession()

    Note over RT: On dispose(), remaining<br/>ephemeral threads deleted.<br/>Errors swallowed. Dedup<br/>via _deletedThreadIds Set.
```

Sessions default to `ephemeral: true`. The thread is deleted on the
backend when the session completes or when the runtime is disposed.
Non-ephemeral sessions (`ephemeral: false`) skip thread deletion —
useful for persistent conversations.

## dispose() sequence

```mermaid
sequenceDiagram
    participant Caller
    participant RT as AgentRuntime
    participant S1 as Session A
    participant S2 as Session B
    participant API as SoliplexApi

    Caller->>RT: dispose()
    RT->>RT: _disposed = true

    RT->>S1: cancel()
    RT->>S2: cancel()

    RT->>API: deleteThread() (ephemeral S1)
    RT->>API: deleteThread() (ephemeral S2)

    RT->>S1: dispose()
    RT->>S2: dispose()

    RT->>RT: sessions.clear()
    RT->>RT: sessionController.close()
```

After `dispose()`, any call to `spawn()` throws `StateError`.

## Usage examples

### Single agent

```dart
final runtime = AgentRuntime(
  api: api,
  agUiClient: agUiClient,
  toolRegistryResolver: (roomId) async => registry,
  platform: NativePlatformConstraints(),
  logger: logger,
);

final session = await runtime.spawn(
  roomId: 'weather',
  prompt: 'Do I need an umbrella?',
);

final result = await session.result;
switch (result) {
  case AgentSuccess(:final output):
    print(output); // "Yes, bring an umbrella."
  case AgentFailure(:final reason):
    print('Failed: $reason');
  case AgentTimedOut(:final elapsed):
    print('Timed out after $elapsed');
}

await runtime.dispose();
```

### Parallel agents with waitAll

```dart
final s1 = await runtime.spawn(roomId: 'weather', prompt: 'NYC weather?');
final s2 = await runtime.spawn(roomId: 'weather', prompt: 'London weather?');
final s3 = await runtime.spawn(roomId: 'weather', prompt: 'Tokyo weather?');

final results = await runtime.waitAll(
  [s1, s2, s3],
  timeout: Duration(seconds: 30),
);

for (final result in results) {
  switch (result) {
    case AgentSuccess(:final output):
      print(output);
    case AgentFailure(:final reason):
      print('One failed: $reason');
    case AgentTimedOut():
      print('One timed out');
  }
}
```

### Race with waitAny

```dart
final s1 = await runtime.spawn(roomId: 'fast-model', prompt: query);
final s2 = await runtime.spawn(roomId: 'slow-model', prompt: query);

final first = await runtime.waitAny([s1, s2]);
await runtime.cancelAll(); // cancel the loser
```
