# Design Documents

## Reading Order

1. **[soliplex-agent-package.md](soliplex-agent-package.md)** — Canonical
   component spec. All interfaces, package structure, implementation phases,
   and dependency injection patterns. **Read this first.**

2. **[monty-host-capabilities-integration.md](monty-host-capabilities-integration.md)**
   — Wiring guide. How `soliplex_interpreter_monty` integrates with `soliplex_agent`
   via `HostApi` + direct `ToolRegistry` injection. Call flows, bridge
   rewiring, platform discrimination.

3. **[agent-runtime-vision.md](agent-runtime-vision.md)** — Product vision.
   LLM-authored orchestration, use cases, Python API surface, UX boundary,
   Monty language limitations.

## Dependency Diagram

```text
Flutter App
  ├── soliplex_interpreter_monty        (Python bridge, host functions)
  │     └── soliplex_agent  (orchestration, runtime, interfaces)
  │           └── soliplex_client  (API, AG-UI, domain models)
  │                 └── soliplex_logging
  └── soliplex_client_native  (platform HTTP adapters)
```

## Glossary

| Term | Definition |
|------|-----------|
| `AgentRuntime` | Multi-session coordinator. Manages concurrent agent sessions spawned by Python scripts. Lives in `soliplex_agent`. |
| `AgentSession` | Handle for a spawned agent session. Wraps a `(room, thread)` tuple + `RunOrchestrator`. |
| `AgentResult` | Sealed type: `AgentSuccess`, `AgentFailure`, `AgentTimedOut`. |
| `HostApi` | Abstract interface for the GUI + native platform boundary. Covers DataFrame/chart registration and `invoke()` dispatch. Implemented by Flutter, mocked in tests. |
| `HostFunction` | A single callable registered on the Monty bridge. Maps a Python function name to a Dart handler. |
| `MontyBridge` | The Python execution bridge. Runs a start/resume loop, dispatching `MontyPending` calls to registered host functions. |
| `PlatformConstraints` | Capability flags: parallel execution, async mode, max concurrent bridges, reentrant interpreter. Global per app instance. |
| `RunOrchestrator` | Core single-run orchestration. Manages the AG-UI event stream, tool execution loop, and state transitions. One per session. |
| `ThreadKey` | `({String serverId, String roomId, String threadId})` — fully qualified thread identifier across servers. |
| `ToolRegistry` | Room-scoped tool execution. Contains `ClientTool` entries with executor closures. Constructed by Flutter, injected into bridge/orchestrator. |
| `ToolRegistryResolver` | `Future<ToolRegistry> Function(String roomId)` — factory for room-scoped registries. Flutter implements, runtime consumes. |

## Guides

1. **[orchestration-guide.md](orchestration-guide.md)** —
   RunOrchestrator state machine, startRun flow, tool yielding
   semantics, AgentSession auto-execute loop.

1. **[runtime-guide.md](runtime-guide.md)** — AgentRuntime facade:
   spawn flow, concurrency model, WASM guard, waitAll/waitAny,
   error propagation, ephemeral thread lifecycle, usage examples.

## Diagrams

- **[diagrams.md](diagrams.md)** — Mermaid architecture diagrams: package
  layers, RunOrchestrator state machine, milestone roadmap, data flow,
  ThreadKey identity model. Render in GitHub or any Mermaid viewer.

## Implementation

- **[implementation-milestones.md](implementation-milestones.md)** — 8-milestone
  build plan with capability gates, agent roles, and stop points.

## Archive

- [`archive/review-concerns.md`](archive/review-concerns.md) — Design
  review checklist from the visioning session. All items resolved.
