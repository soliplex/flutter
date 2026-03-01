# Architecture Diagrams

## Package Architecture

```mermaid
graph TD
    subgraph FlutterApp["Flutter App"]
        UI["UI Features"]
        Providers["Riverpod Providers"]
        Router["GoRouter"]
    end

    subgraph Agent["soliplex_agent (pure Dart)"]
        Runtime["AgentRuntime<br/>spawn / waitAll / waitAny"]
        Session["AgentSession<br/>ThreadKey + RunOrchestrator"]
        Orchestrator["RunOrchestrator<br/>state machine + tool loop"]
        Registry["ToolRegistry<br/>register / lookup / execute"]
        HostApi["HostApi<br/>platform boundary interface"]
        Constraints["PlatformConstraints<br/>WASM safety flags"]
    end

    subgraph Monty["soliplex_interpreter_monty"]
        Bridge["MontyBridge"]
        HostFns["HostFunctions"]
        DataFrame["DataFrame Engine"]
    end

    subgraph Client["soliplex_client"]
        Api["SoliplexApi"]
        AgUi["AgUiClient"]
        Domain["Domain Models"]
    end

    FlutterApp --> Agent
    Agent --> Client
    Monty --> Agent
    Monty --> Client
    Runtime --> Session
    Session --> Orchestrator
    Orchestrator --> Registry
    Orchestrator --> Api
    Orchestrator --> AgUi
    Bridge -.->|implements| HostApi
    Monty -.->|depends on| HostApi

    style Agent fill:#d4edda,stroke:#28a745
    style Monty fill:#e8d5f5,stroke:#7b2d8e
    style Client fill:#ffe0b2,stroke:#e65100
    style FlutterApp fill:#bbdefb,stroke:#1565c0
```

## RunOrchestrator State Machine

Reflects the actual 6-state sealed hierarchy in `run_state.dart`.

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> Running : startRun()
    Running --> ToolYielding : RunFinished + pending client tools
    Running --> Completed : RunFinished + no pending tools
    Running --> Failed : RunError / stream error / onDone without terminal
    Running --> Cancelled : cancelRun()

    ToolYielding --> Running : submitToolOutputs() → new backend run
    ToolYielding --> Failed : depth limit exceeded (10)
    ToolYielding --> Cancelled : cancelRun()

    Completed --> [*]
    Failed --> [*]
    Cancelled --> [*]

    note right of ToolYielding
        yield/resume loop
        depth-limited to 10
    end note
```

## Milestone Roadmap

```mermaid
graph LR
    M1["<b>M1</b><br/>Package Scaffold<br/>+ Core Types"]
    M2["<b>M2</b><br/>Core Interfaces<br/>+ Mocks"]
    M3["<b>M3</b><br/>Tool Registry<br/>+ Execution"]
    M4["<b>M4</b><br/>RunOrchestrator<br/>Happy Path"]
    M5["<b>M5</b><br/>Tool Yielding<br/>+ Resume"]
    M6["<b>M6</b><br/>AgentRuntime<br/>Facade"]
    M7["<b>M7</b><br/>Backend<br/>Integration"]
    M8["<b>M8</b><br/>Test Harness<br/>+ Shared Types"]

    M1 --> M2 --> M3 --> M4 --> M5 --> M6 --> M7 --> M8

    M2 -.- Stop1(("unblock<br/>bridge"))
    M5 -.- Stop2(("MVP<br/>agent"))
    M7 -.- Stop3(("proven<br/>against real<br/>rooms"))

    style M1 fill:#e0e0e0,stroke:#616161
    style M2 fill:#e0e0e0,stroke:#616161
    style M3 fill:#e0e0e0,stroke:#616161
    style M4 fill:#e0e0e0,stroke:#616161
    style M5 fill:#e0e0e0,stroke:#616161
    style M6 fill:#e0e0e0,stroke:#616161
    style M7 fill:#c8e6c9,stroke:#2e7d32,stroke-width:3px
    style M8 fill:#b2dfdb,stroke:#00695c
    style Stop1 fill:#fff,stroke:#1565c0
    style Stop2 fill:#fff,stroke:#e65100
    style Stop3 fill:#fff,stroke:#00695c
```

## Data Flow — Prompt to Response

```mermaid
sequenceDiagram
    actor User
    participant UI as Flutter UI
    participant RT as AgentRuntime
    participant Session as AgentSession
    participant RO as RunOrchestrator
    participant TR as ToolRegistry
    participant AGUI as AgUiClient
    participant BE as SoliplexApi / Backend

    User->>UI: enters prompt
    UI->>RT: spawn(roomId, prompt)
    RT->>BE: createThread(roomId)
    BE-->>RT: ThreadInfo { id }
    RT->>RT: resolveToolRegistry(roomId)
    RT->>Session: create AgentSession + RunOrchestrator

    Session->>RO: startRun(key, userMessage)
    RO->>BE: createRun(roomId, threadId)
    BE-->>RO: RunInfo { id }
    RO->>AGUI: runAgent(endpoint, input)
    activate AGUI

    loop Tool Yield/Resume (depth-limited to 10)
        AGUI-->>RO: ToolCallStart/Args/End events
        AGUI-->>RO: RunFinishedEvent (with pending tools)
        RO-->>Session: ToolYieldingState
        Session->>TR: execute(toolCall) per tool
        TR-->>Session: result string
        Session->>RO: submitToolOutputs(executed)
        RO->>BE: createRun() (new run for continuation)
        RO->>AGUI: runAgent(endpoint, input)
    end

    AGUI-->>RO: RunFinishedEvent (no pending tools)
    deactivate AGUI
    RO-->>Session: CompletedState

    Session-->>RT: AgentSuccess
    RT-->>UI: session.result completes
    UI-->>User: display response

    Note over RO,TR: ThreadKey = {serverId, roomId, threadId}
```

## ThreadKey Identity Model

```mermaid
graph TD
    TK["<b>ThreadKey</b><br/>{serverId, roomId, threadId}"]

    S["serverId<br/><i>which backend instance</i>"]
    R["roomId<br/><i>which room / agent config</i>"]
    T["threadId<br/><i>which conversation thread</i>"]

    TK --- S
    TK --- R
    TK --- T

    S --> S1["staging.soliplex.io"]
    S --> S2["localhost:8000"]
    R --> R1["echo-room"]
    R --> R2["tool-call-room"]
    T --> T1["thread-abc-123"]
    T --> T2["thread-def-456"]

    style TK fill:#d4edda,stroke:#28a745,stroke-width:2px
    style S fill:#bbdefb,stroke:#1565c0
    style R fill:#ffe0b2,stroke:#e65100
    style T fill:#e8d5f5,stroke:#7b2d8e
```
