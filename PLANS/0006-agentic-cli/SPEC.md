# Feature Specification: Agentic CLI

## Overview

`soliplex_cli` is a headless Dart CLI that exposes the Soliplex backend through
an agentic interface. The LLM can instrument the local machine through
**client-side tools** — filesystem operations, git history, GitHub API
lookups — enabling queries like:

> "Find the file that talks about the M6 specification and check GitHub for
> what checkin that landed"

The CLI replaces Flutter's presentation layer with a stdin/stdout REPL while
reusing the entire `soliplex_client` package (pure Dart, no Flutter imports).
The user types a question, the LLM reasons over it, requests tools as needed,
the CLI executes them locally, sends results back, and the LLM produces a
final answer.

### Why it matters

- **Developer workflow integration:** Query project knowledge from the
  terminal without switching to a browser or Flutter app.
- **Composability:** Pipe output to other tools (`jq`, `grep`, `less`).
- **Validation of pure-Dart split:** Proves `soliplex_client` is truly
  Flutter-free by running it in a non-Flutter Dart process.
- **Foundation for automation:** Scripts and CI jobs can query Soliplex
  programmatically once the CLI exists.

## How It Works

The core mechanism is an LLM-driven tool execution loop. The CLI sends a user
message to the backend, streams the response, and when the LLM requests tools,
executes them locally and submits the results via a continuation run.

```text
┌──────────┐          ┌───────────────┐          ┌─────────────┐
│  User    │  stdin   │  soliplex_cli │  REST/   │  Soliplex   │
│ (REPL)   │────────> │               │  SSE     │  Backend    │
│          │ <────────│  ToolRegistry │ <──────> │  (AG-UI)    │
│          │  stdout  │  EventProc.   │          │             │
└──────────┘          └───────┬───────┘          └─────────────┘
                              │
                   ┌──────────┴──────────┐
                   │  Local Tool Exec.   │
                   │  fs, git, gh, ...   │
                   └─────────────────────┘
```

### Tool execution loop (single hop)

```text
1. User types query
2. CLI builds SimpleRunAgentInput with tool definitions from ToolRegistry
3. CLI calls api.createRun() + streams AG-UI events
4. Event processor accumulates ToolCallInfo (streaming → pending)
5. Stream completes (RunFinished / onDone)
6. CLI detects pending tool calls in conversation.toolCalls
7. CLI executes tools locally via ToolRegistry.execute()
8. CLI synthesizes ToolCallMessage, appends to conversation
9. CLI creates continuation run with tool results in AG-UI messages
10. Steps 3-9 repeat until no pending tools (multi-hop)
11. Final text response printed to stdout
```

### Multi-hop sequence diagram

```text
Run 1:  RunStarted → ToolCallStart(A) → Args(A) → End(A) → RunFinished
        ↓ onDone: pending tools detected
        Execute tool A locally → result "42"
        Synthesize ToolCallMessage(A: completed, result: "42")
        ↓
Run 2:  createRun() with [UserMessage, AssistantMessage(toolCalls), ToolMessage(result)]
        RunStarted → ToolCallStart(B) → Args(B) → End(B) → RunFinished
        ↓ onDone: pending tools detected
        Execute tool B locally → result "PR #405"
        ↓
Run 3:  createRun() with accumulated messages
        RunStarted → TextStart → TextContent("The M6 spec...") → TextEnd → RunFinished
        ↓ onDone: no pending tools
        Print response to stdout
```

## Building Blocks

The following components already exist in `soliplex_client` and are directly
usable from a CLI context (no Flutter dependency).

### ToolRegistry + ClientTool + ToolExecutor

**File:** `packages/soliplex_client/lib/src/application/tool_registry.dart`

Immutable registry of client-side tools. Each `ClientTool` pairs an AG-UI
`Tool` definition (sent to the backend so the model knows the tool exists)
with a `ToolExecutor` function that runs locally.

```dart
typedef ToolExecutor = Future<String> Function(ToolCallInfo toolCall);

class ClientTool {
  final Tool definition;
  final ToolExecutor executor;
}

class ToolRegistry {
  ToolRegistry register(ClientTool tool);
  ToolRegistry alias(String aliasName, String canonicalName);
  ClientTool lookup(String name);
  Future<String> execute(ToolCallInfo toolCall);
  bool contains(String name);
  List<Tool> get toolDefinitions;
}
```

The registry is immutable — each `register()` returns a new instance. Build
it once at CLI startup and pass `toolDefinitions` to every run input.

### SoliplexApi

**File:** `packages/soliplex_client/lib/src/api/soliplex_api.dart`

REST client for all backend CRUD operations. Built on `HttpTransport` (pure
Dart HTTP, no Flutter). Key methods for the CLI:

- `getRooms()` / `getRoom(roomId)` — list and select rooms
- `createThread(roomId)` — start a conversation
- `createRun(roomId, threadId)` — create a run for continuation
- `getThreadHistory(roomId, threadId)` — replay previous conversations

### processEvent()

**File:** `packages/soliplex_client/lib/src/application/agui_event_processor.dart`

Pure function that takes `(Conversation, StreamingState, BaseEvent)` and
returns `EventProcessingResult` with updated domain and streaming state.
Handles the full AG-UI event vocabulary:

- Run lifecycle: `RunStartedEvent`, `RunFinishedEvent`, `RunErrorEvent`
- Text streaming: `TextMessageStart/Content/End`
- Tool calls: `ToolCallStart/Args/End` (accumulates `ToolCallInfo` with
  `streaming → pending` status transitions)
- State management: `StateSnapshotEvent`, `StateDeltaEvent`

### DartHttpClient / HttpTransport

**Files:**

- `packages/soliplex_client/lib/src/http/dart_http_client.dart`
- `packages/soliplex_client/lib/src/http/http_transport.dart`

Pure Dart HTTP stack. `DartHttpClient` wraps `dart:io`'s `HttpClient`.
`HttpTransport` adds JSON serialization, error mapping, and cancel token
support. No Flutter, no platform channels — works in any Dart process.

### AG-UI Message Mapper

**File:** `packages/soliplex_client/lib/src/api/agui_message_mapper.dart`

`convertToAgui(List<ChatMessage>)` converts domain messages to AG-UI protocol
format. Handles `ToolCallMessage` → `AssistantMessage` (with toolCalls) +
`ToolMessage` (with results). Essential for building continuation run inputs.

## What M6 Adds

M6 (client-side tool calling, slices 1-3) provides the **orchestration gap**
between having tools registered and actually executing them in a loop.

**Reference:** `docs/planning/client-tool-calls-plan.md`

### Slice 1: ToolCallArgs accumulation in event processor

**Spec:** `docs/planning/slice-1-tool-registry-provider.md`

- Wires `ToolRegistry` into a Riverpod provider (Flutter app only — CLI
  will use direct wiring instead)
- Event processor changes: `ToolCallStartEvent` creates `ToolCallInfo` with
  `status: streaming`, `ToolCallArgsEvent` accumulates argument deltas,
  `ToolCallEndEvent` transitions to `status: pending`
- Without this, tool call arguments are not captured from the event stream

### Slice 2: Mock LLM harness

**Spec:** `docs/planning/slice-2-mock-llm-harness.md`

- `buildMockEventStream(List<BaseEvent>)` for deterministic offline testing
- `FakeAgUiClient` that returns scripted event streams per run
- Proves tool execution works end-to-end without a live backend

### Slice 3: ExecutingToolsState + continuation loop

**Spec:** `docs/planning/slice-3-orchestration.md`

This is the critical piece. It adds:

- **`ExecutingToolsState`** — new `ActiveRunState` subclass representing the
  phase between stream completion and continuation run start
- **`_executeToolsAndContinue(handle, {depth})`** — the core orchestration
  method: execute pending tools via `Future.wait`, synthesize
  `ToolCallMessage`, create continuation run, start new stream
- **`replaceRun` on RunRegistry** — atomic CAS for continuation run
  registration (prevents TOCTOU race)
- **Circuit breaker** — `depth >= _maxContinuationDepth` (default 10) aborts
  infinite multi-hop loops
- **8 safety checks** — every code path reaches a terminal state; no path
  leaves `ExecutingToolsState` stranded

The CLI needs to reimplement this orchestration loop **without**
`ActiveRunNotifier` or Riverpod. See
[CLI-Specific Orchestration](#cli-specific-orchestration) below.

## Proposed CLI Tools

Concrete tool definitions the CLI registers at startup. Each tool is a
`ClientTool` with an AG-UI `Tool` definition (JSON Schema for parameters)
and a local executor function.

### Filesystem tools

#### `fs_list`

List files in a directory.

| Field | Value |
|-------|-------|
| **Name** | `fs_list` |
| **Description** | List files and directories at a given path |
| **Parameters** | `path` (string, required): directory path |
| | `recursive` (boolean, optional): recurse into subdirectories |
| **Returns** | Newline-separated list of relative paths |
| **Executor** | `Directory(path).list()` with depth control |

#### `fs_read`

Read file contents.

| Field | Value |
|-------|-------|
| **Name** | `fs_read` |
| **Description** | Read the contents of a file |
| **Parameters** | `path` (string, required): file path |
| | `max_lines` (integer, optional): limit output to first N lines |
| **Returns** | File contents as string |
| **Executor** | `File(path).readAsString()` with line truncation |

#### `fs_find`

Search for files by glob or regex pattern.

| Field | Value |
|-------|-------|
| **Name** | `fs_find` |
| **Description** | Find files matching a glob or regex pattern |
| **Parameters** | `pattern` (string, required): glob or regex pattern |
| | `path` (string, optional): root directory (default: cwd) |
| | `type` (string, optional): `"file"`, `"directory"`, or `"any"` |
| **Returns** | Newline-separated list of matching paths |
| **Executor** | `Glob` from `package:glob` or `RegExp` match on `Directory.list()` |

### Git tools

#### `git_log`

View git commit history.

| Field | Value |
|-------|-------|
| **Name** | `git_log` |
| **Description** | Show git commit history |
| **Parameters** | `path` (string, optional): repository path (default: cwd) |
| | `max_count` (integer, optional): limit number of commits (default: 20) |
| | `author` (string, optional): filter by author |
| | `since` (string, optional): commits after date (ISO 8601) |
| | `grep` (string, optional): filter by commit message pattern |
| **Returns** | Formatted commit log (hash, author, date, message) |
| **Executor** | `Process.run('git', ['log', ...])` |

#### `git_diff`

Show changes for a commit or range.

| Field | Value |
|-------|-------|
| **Name** | `git_diff` |
| **Description** | Show the diff for a commit or range of commits |
| **Parameters** | `ref` (string, required): commit hash, branch, or range |
| | `path` (string, optional): repository path (default: cwd) |
| | `stat_only` (boolean, optional): show only file change summary |
| **Returns** | Unified diff output |
| **Executor** | `Process.run('git', ['diff', ref])` or `git show ref` |

### GitHub tools

#### `gh_search`

Search GitHub issues, PRs, and commits.

| Field | Value |
|-------|-------|
| **Name** | `gh_search` |
| **Description** | Search GitHub issues, pull requests, or commits |
| **Parameters** | `query` (string, required): search query |
| | `type` (string, optional): `"issues"`, `"prs"`, `"commits"` (default: all) |
| | `repo` (string, optional): owner/repo to scope search |
| | `max_results` (integer, optional): limit results (default: 10) |
| **Returns** | Formatted search results (number, title, URL, status) |
| **Executor** | `Process.run('gh', ['search', type, query, ...])` |

#### `gh_pr_view`

View pull request details.

| Field | Value |
|-------|-------|
| **Name** | `gh_pr_view` |
| **Description** | View details of a GitHub pull request |
| **Parameters** | `number` (integer, required): PR number |
| | `repo` (string, optional): owner/repo (default: current repo) |
| **Returns** | PR title, body, status, author, review state, files changed |
| **Executor** | `Process.run('gh', ['pr', 'view', number, '--json', ...])` |

## Package Structure

```text
~/dev/soliplex_cli/
├── bin/
│   └── soliplex_cli.dart          # Entry point: parse args, build registry, run REPL
├── lib/
│   ├── src/
│   │   ├── cli_orchestrator.dart   # Orchestration loop (replaces ActiveRunNotifier)
│   │   ├── repl.dart               # stdin/stdout REPL + output formatting
│   │   ├── tools/
│   │   │   ├── fs_tools.dart       # fs_list, fs_read, fs_find
│   │   │   ├── git_tools.dart      # git_log, git_diff
│   │   │   └── gh_tools.dart       # gh_search, gh_pr_view
│   │   └── tool_builder.dart       # Builds ToolRegistry from tool modules
│   └── soliplex_cli.dart           # Public API barrel file
├── test/
│   ├── cli_orchestrator_test.dart  # Orchestration loop tests (mock event streams)
│   ├── tools/
│   │   ├── fs_tools_test.dart
│   │   ├── git_tools_test.dart
│   │   └── gh_tools_test.dart
│   └── repl_test.dart
├── pubspec.yaml                    # Depends on soliplex_client (path dependency)
├── analysis_options.yaml
└── CHANGELOG.md
```

### pubspec.yaml (key dependencies)

```yaml
name: soliplex_cli
environment:
  sdk: ^3.6.0

dependencies:
  soliplex_client:
    path: ../soliplex-flutter-charting/packages/soliplex_client
  ag_ui:
    path: ../soliplex-flutter-charting/packages/ag_ui
  args: ^2.5.0    # CLI argument parsing
  glob: ^2.1.0    # fs_find tool

dev_dependencies:
  test: ^1.25.0
  mocktail: ^1.0.0
```

## Example Interaction

Full trace of the motivating query showing the tool execution loop.

### User query

```text
$ soliplex_cli --room my-project
> Find the file that talks about the M6 specification and check GitHub for what checkin that landed
```

### Run 1: LLM requests filesystem search

```text
← RunStartedEvent(runId: "run-001")
← ToolCallStartEvent(id: "tc-1", name: "fs_find")
← ToolCallArgsEvent(id: "tc-1", delta: '{"pattern": "**/M6*", "path": "."}')
← ToolCallEndEvent(id: "tc-1")
← RunFinishedEvent()
```

Event processor state: `ToolCallInfo(id: "tc-1", name: "fs_find", status: pending, arguments: '{"pattern": "**/M6*", "path": "."}')`

### CLI executes fs_find locally

```text
→ ToolRegistry.execute(tc-1)
→ Glob("**/M6*").list(".")
← Result: "docs/planning/client-tool-calls-plan.md\ndocs/specs/m6-specification.md"
```

### Run 2: LLM reads the file and searches GitHub

```text
Continuation run with ToolMessage(result: "docs/planning/...")

← RunStartedEvent(runId: "run-002")
← ToolCallStartEvent(id: "tc-2", name: "fs_read")
← ToolCallArgsEvent(id: "tc-2", delta: '{"path": "docs/specs/m6-specification.md", "max_lines": 50}')
← ToolCallEndEvent(id: "tc-2")
← ToolCallStartEvent(id: "tc-3", name: "gh_search")
← ToolCallArgsEvent(id: "tc-3", delta: '{"query": "M6 specification", "type": "commits", "repo": "soliplex/soliplex"}')
← ToolCallEndEvent(id: "tc-3")
← RunFinishedEvent()
```

### CLI executes fs_read and gh_search locally

```text
→ Execute tc-2: File("docs/specs/m6-specification.md").readAsString()
→ Execute tc-3: Process.run("gh", ["search", "commits", "M6 specification", ...])
← tc-2 result: "# M6 Specification\n\nClient-side tool calling..."
← tc-3 result: "abc1234 feat(tools): implement M6 client tool calling (2025-01-15)"
```

### Run 3: LLM responds with final answer

```text
← RunStartedEvent(runId: "run-003")
← TextMessageStartEvent(id: "msg-1", role: assistant)
← TextMessageContentEvent(id: "msg-1", delta: "The M6 specification is documented in...")
← TextMessageEndEvent(id: "msg-1")
← RunFinishedEvent()
```

### CLI output

```text
The M6 specification is documented in `docs/specs/m6-specification.md`. It
covers client-side tool calling — the ability for the LLM to request tools
that execute on the client rather than the server.

The implementation landed in commit `abc1234` on 2025-01-15:
"feat(tools): implement M6 client tool calling"
```

## CLI-Specific Orchestration

The Flutter app uses `ActiveRunNotifier` (a Riverpod `AsyncNotifier`) for
orchestration. The CLI cannot use Riverpod or Flutter widgets. Instead, it
implements the same loop with direct wiring.

### What changes

| Concern | Flutter (ActiveRunNotifier) | CLI (CliOrchestrator) |
|---------|---------------------------|----------------------|
| Dependency injection | Riverpod `ref.watch()` | Constructor parameters |
| State management | `ActiveRunState` subclasses, `state =` | Local variables in async method |
| Event stream | `_establishSubscription` with `StreamSubscription` | `await for` on event stream |
| Tool registry | `toolRegistryProvider` | Passed directly to constructor |
| UI sync | `_syncUiState(handle, state)` | `stdout.writeln()` |
| Cancellation | `CancelToken` on `RunHandle` | `CancelToken` as local variable |
| Concurrent threads | `RunRegistry` multi-handle | Single-threaded REPL (one run at a time) |

### CliOrchestrator sketch

```dart
class CliOrchestrator {
  CliOrchestrator({
    required SoliplexApi api,
    required ToolRegistry toolRegistry,
    required AgUiClient agUiClient,
  });

  /// Sends a user message and processes the full tool-calling loop.
  ///
  /// Returns the final assistant response text.
  Future<String> run({
    required String roomId,
    required String threadId,
    required String userMessage,
    required List<ChatMessage> history,
  }) async {
    var conversation = /* build from history + new user message */;
    var depth = 0;

    while (depth < maxContinuationDepth) {
      // 1. Create run + stream events
      final messages = convertToAgui(conversation.messages);
      final eventStream = agUiClient.runAgent(threadId, input);

      // 2. Process events (pure function loop)
      var streaming = const AwaitingText() as StreamingState;
      await for (final event in eventStream) {
        final result = processEvent(conversation, streaming, event);
        conversation = result.conversation;
        streaming = result.streaming;
      }

      // 3. Check for pending tools
      final pending = conversation.toolCalls
          .where((tc) => tc.status == ToolCallStatus.pending)
          .toList();

      if (pending.isEmpty) break; // Done — no tools requested

      // 4. Execute tools locally
      stdout.writeln('Executing: ${pending.map((t) => t.name).join(", ")}');
      for (final tc in pending) {
        try {
          final result = await toolRegistry.execute(tc);
          tc = tc.copyWith(status: ToolCallStatus.completed, result: result);
        } catch (e) {
          tc = tc.copyWith(status: ToolCallStatus.failed, result: 'Error: $e');
        }
      }

      // 5. Synthesize ToolCallMessage, clear toolCalls, increment depth
      conversation = conversation
          .withAppendedMessage(ToolCallMessage.fromExecuted(pending))
          .copyWith(toolCalls: []);
      depth++;
    }

    // 6. Return last assistant message
    return conversation.messages.last.text;
  }

  static const maxContinuationDepth = 10;
}
```

### Key simplifications vs Flutter

- **No `RunHandle` / `RunRegistry`:** The CLI runs one conversation at a
  time. No concurrent thread management needed.
- **No `_currentHandle` guard:** Single-threaded — no background threads
  competing for UI state.
- **No `_syncUiState`:** Status updates go directly to stdout.
- **`await for` instead of `StreamSubscription`:** Synchronous iteration
  over the event stream is simpler and sufficient for a REPL.
- **No `replaceRun` CAS:** No concurrent user re-sends in a REPL context.
  The user waits for the response before typing the next query.

### What stays the same

- `processEvent()` — same pure function, same event handling
- `ToolRegistry` — same immutable registry, same `execute()` method
- `convertToAgui()` — same message mapper for continuation runs
- `SoliplexApi` — same REST client for `createRun`, `createThread`, etc.
- Circuit breaker — same `maxContinuationDepth` limit
- Per-tool error isolation — same try/catch per tool, failed tools still
  produce `ToolMessage` for the model

## Dependencies

### M6 slices 1-3 must land first

| Slice | What the CLI needs from it |
|-------|---------------------------|
| **Slice 1** | `ToolCallArgsEvent` accumulation in `processEvent()`. Without this, tool call arguments are lost during event processing. The Riverpod provider wiring is Flutter-only and not needed by the CLI. |
| **Slice 2** | Mock LLM harness (`buildMockEventStream`, `FakeAgUiClient`). Required for testing `CliOrchestrator` without a live backend. |
| **Slice 3** | `ToolCallMessage.fromExecuted()` domain helper for synthesizing tool result messages. The `ExecutingToolsState` and `_executeToolsAndContinue` are Flutter-specific but the domain helper is in `soliplex_client`. |

### Other dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| `soliplex_client` | Ready | Pure Dart, all needed APIs exist |
| `ag_ui` | Ready | AG-UI protocol types and event decoder |
| `dart:io` | Ready | For `Process.run` (git, gh), `File`, `Directory` |
| `package:args` | Add | CLI argument parsing |
| `package:glob` | Add | For `fs_find` tool |
| `gh` CLI | Runtime | Must be installed and authenticated for `gh_*` tools |
| `git` CLI | Runtime | Must be available on PATH for `git_*` tools |

## Open Questions

### Security and sandboxing

- **Path traversal:** Should `fs_read` and `fs_list` be restricted to the
  current working directory or a configured allowlist? The LLM could request
  reading `/etc/passwd` or `~/.ssh/id_rsa`.
- **Command injection:** `git_log` and `gh_search` pass arguments to
  `Process.run`. Arguments must be passed as list elements (not shell
  strings) to prevent injection. Validate this in tool executors.
- **Sandboxing depth:** Should there be a configurable root directory that
  all filesystem tools are jailed to?

### Tool approval UX

- **Auto-approve vs confirm:** Should the CLI auto-execute all tool calls,
  or prompt the user for approval before each execution?
- **Trust levels:** Could tools be marked as "safe" (auto-approve) vs
  "dangerous" (require confirmation)?
- **Verbose mode:** Should the CLI print tool calls and results by default,
  or only in `--verbose` mode?

### Output formatting

- **Markdown rendering:** Should the CLI render markdown (bold, headers,
  code blocks) in the terminal using ANSI escape codes?
- **Streaming output:** Should text be printed as it streams token by token,
  or buffered until the full response is ready?
- **Tool output:** Should tool results be printed to the user or kept hidden
  (only sent to the LLM)?

### Authentication

- **Token management:** How does the CLI authenticate with the Soliplex
  backend? Config file, environment variable, or interactive login?
- **Room selection:** CLI flag (`--room`) or interactive picker?

### Scope of initial release

- **Minimum viable tool set:** Are the 7 proposed tools sufficient for v1,
  or should we start with fewer (e.g., just `fs_read` and `git_log`)?
- **Conversation persistence:** Should the CLI support resuming previous
  threads, or is each session ephemeral?
