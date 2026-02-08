# ADR-002: Agent-in-the-Loop E2E Testing

**Status:** Accepted

**Date:** 2026-02-08

**Branch:** `feat/patrol-client-tools`

## Context

Soliplex has a growing Patrol E2E test suite (Phases A-C: smoke, live chat,
OIDC auth, settings) and a structured logging subsystem with per-domain
loggers, MemorySink capture, and backend log shipping. These two systems
operate independently: tests run via CLI, logs ship to the backend, and
failures require manual investigation across terminal output, Xcode logs,
and backend dashboards.

We needed a way to close this loop — let an AI agent run tests, read their
output, correlate with structured logs, and report findings through the
same chat UI that developers already use.

## Decisions

### 1. Client-Side Tool Execution

**Decision:** E2E test execution happens on the Flutter client, not the
Python backend server. The server orchestrates (LLM decides to call
`patrol_run`), the client executes (has GUI access and local environment).

**Rationale:** `patrol test` requires macOS WindowServer access for
xcodebuild. The Python server runs headless — spawning xcodebuild from
a server process fails with exit code 65 ("no supported run destinations").
The Flutter client inherently has GUI access because it IS a GUI app.

**Mechanism:**

```text
Server (pydantic_ai)          Client (Flutter)
────────────────────          ──────────────────
LLM decides: call             ToolRegistry has
patrol_run(smoke_test)        patrol_run registered
        │                              │
        ▼                              ▼
AG-UI SSE: TOOL_CALL ───────► ActiveRunNotifier
                               hasExecutor() ✓
                               Process.run(patrol)
                                       │
        ◄──────────────────── POST tool result
        │
Agent: "All tests passed"
```

**Trade-off:** Client-side execution means tests only run when a developer
has the app open. This is acceptable because E2E tests require a GUI
environment regardless, and CI runners would use the Patrol CLI directly.

### 2. Feedback Loop: Tests ↔ Logging ↔ Agent

**Decision:** Establish a three-way feedback loop where the agent can
trigger tests, read structured log output, and correlate failures with
log events — all within a single chat conversation.

**Architecture:**

```text
┌─────────────────────────────────────────────────┐
│                 Patrol Room                       │
│              (Chat Conversation)                  │
│                                                   │
│  User: "Run the smoke test"                       │
│  Agent: [calls patrol_run tool]                   │
│  Agent: "PASSED — 2 tests in 6.1s"               │
│                                                   │
│  User: "Run live_chat, it's been flaky"           │
│  Agent: [calls patrol_run tool]                   │
│  Agent: "FAILED — timeout waiting for RUN_STARTED │
│          Last log: HTTP 200 /rooms but no SSE"    │
│  Agent: "The backend returned rooms but the AG-UI │
│          stream never started. Check if the SSE   │
│          endpoint is responding."                  │
└──────────────────┬──────────────────────────────┘
                   │
    ┌──────────────┼──────────────┐
    ▼              ▼              ▼
┌────────┐  ┌──────────┐  ┌──────────────┐
│ Patrol │  │ Logging  │  │ Log Shipping │
│ Tests  │  │ Subsystem│  │ (Backend)    │
│        │  │          │  │              │
│ smoke  │  │ Loggers  │  │ DiskQueue    │
│ live   │◄─┤ Memory   │  │ BackendSink  │
│ oidc   │  │ Sink     │  │ OTel attrs   │
│ settings│ │ Stdout   │  │              │
└────────┘  └──────────┘  └──────────────┘
```

**Data flow:**

1. **Test execution** — `patrol_run` executor spawns `patrol test`, captures
   stdout/stderr, returns truncated output (last 2000 chars) as tool result
2. **Log capture** — tests use `TestLogHarness` with `MemorySink` to capture
   structured logs during execution. On failure, `harness.dumpLogs(last: 50)`
   writes the log buffer to stdout, which becomes part of the tool result
3. **Agent diagnosis** — the LLM receives the tool result containing both
   test output and structured logs, enabling it to correlate failures with
   specific log events (e.g., "HTTP 200 on /rooms but no SSE stream started")
4. **Log shipping** — independently, the logging subsystem ships structured
   logs to the backend via `BackendLogSink` + `DiskQueue`, providing a
   persistent audit trail that the agent can reference in future sessions

### 3. Immutable Tool Registry with Builder Pattern

**Decision:** Use an immutable `ToolRegistry` with a builder-style
`.register()` method that returns a new registry instance.

**Rationale:** Riverpod providers are immutable by design. A mutable
registry would require a `StateNotifier`, adding complexity for no benefit.
The builder pattern chains naturally:

```dart
final toolRegistryProvider = Provider<ToolRegistry>((ref) {
  return const ToolRegistry()
      .register(getSecretTool, getSecretExecutor)
      .register(patrolRunTool, patrolRunExecutor);
});
```

### 4. Target Allowlist for Security

**Decision:** The `patrol_run` executor validates the `target` argument
against a compile-time allowlist of test filenames. Any target not in the
list is rejected with an error before spawning a process.

**Rationale:** The tool accepts input from an LLM, which accepts input
from a user typing in chat. Without validation, a prompt injection could
execute arbitrary commands via `patrol test --target ../../malicious.dart`.
The allowlist ensures only known test files can be executed.

**Allowed targets:** `smoke_test.dart`, `live_chat_test.dart`,
`settings_test.dart`, `oidc_test.dart`

### 5. Skill-First, Room-Second

**Decision:** The Patrol skill (`.claude/skills/patrol/SKILL.md`) is the
primary source of test patterns and troubleshooting knowledge. The Patrol
room's system prompt references the same patterns. Both share identical
test inventories and debugging strategies.

**Rationale:** When the app itself is broken, the Patrol room UI may not
load. The CLI skill provides a fallback that works standalone via
`claude --skill patrol`. The room adds AG-UI streaming and chat history
on top, but the core knowledge lives in the skill.

## Consequences

### Positive

- Developers diagnose test failures from the same chat UI they use daily
- Structured logs are available to the agent alongside test output
- The allowlist prevents arbitrary command execution via chat
- Skill-first design ensures testing capability survives app failures
- Backend log shipping creates persistent audit trails across sessions

### Negative

- Client-side execution requires the app to be running (no headless CI)
- `Process.run` blocks until completion — no streaming output in v1
- macOS sandbox must be disabled for debug builds (`app-sandbox: false`)
- Tool result truncation (2000 chars) may lose relevant output context

### Neutral

- The `patrol_run` tool lives in `soliplex_client` (pure Dart package),
  making it available to any Dart consumer, not just the Flutter app
- Server-side `patrol_tools.py` prototype remains as reference but is
  not loaded by the patrol room config

## v2 Follow-ups

Documented in `docs/planning/patrol/patrol-run-v2-followups.md`:

1. **Streaming output** — switch `Process.run` to `Process.start`, pipe
   stdout lines as `STATE_DELTA` events for real-time progress
2. **`--dart-define` config** — pass `backend_url` as compile-time config
   instead of process environment variable
3. **PATH resolution** — resolve `~/.pub-cache/bin/patrol` for macOS GUI
   apps that don't inherit shell PATH

## Implementation Reference

| Component | Location |
|-----------|----------|
| Tool definition + executor | `packages/soliplex_client/lib/src/application/tools/patrol_run_tool.dart` |
| Tool registry | `packages/soliplex_client/lib/src/application/tool_registry.dart` |
| Provider registration | `lib/core/providers/api_provider.dart` (toolRegistryProvider) |
| Client-side execution | `lib/core/providers/active_run_notifier.dart` (_executeToolsAndContinue) |
| Phase E spec | `docs/planning/patrol/phase-e-agent-loop.md` |
| Client tools plan | `docs/planning/patrol/client-tools-plan.md` |
| v2 follow-ups | `docs/planning/patrol/patrol-run-v2-followups.md` |
| Backend prototype | `~/dev/soliplex/src/soliplex/patrol_tools.py` |
| Patrol skill | `.claude/skills/patrol/SKILL.md` |
