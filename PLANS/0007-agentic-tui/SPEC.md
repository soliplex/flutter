# Feature Specification: Agentic TUI

## Overview

`soliplex_tui` is a rich terminal UI for the Soliplex backend, built on the
[nocterm](https://github.com/Norbert515/nocterm) framework. Where `soliplex_cli`
(0006) is a headless stdin/stdout REPL, the TUI provides a full-featured
terminal experience: streaming markdown, a reasoning pane, tool execution
indicators, keyboard shortcuts, and a scrollable chat history.

The primary reference architecture is [cow](https://github.com/jolexxa/cow), a
local LLM chat client built on nocterm that demonstrates streaming text, tool
execution, reasoning panes, and keyboard-driven interaction. The agentic TUI
follows cow's architecture but wires it to Soliplex's AG-UI backend instead of
local llama.cpp.

### Why a separate TUI (vs CLI)

| Concern | CLI (0006) | TUI (0007) |
|---------|-----------|-----------|
| **Output** | `stdout.writeln()` | nocterm component tree |
| **Rendering** | Line-by-line | Differential at 30 fps |
| **Layout** | None | Rows, columns, split panes |
| **Markdown** | Plain text or ANSI | `MarkdownText` component |
| **Tool status** | One-line print | Animated status indicator |
| **Reasoning** | Hidden | Optional split pane |
| **Scrolling** | Terminal scroll buffer | `ListView` + `ScrollController` |
| **State mgmt** | Local variables | Bloc/LogicBloc state machine |

Both share `soliplex_client` (pure Dart) and the same tool definitions.

### Blocked on M6

This spec is blocked on **M6 (client-side tool calling)**, slices 1-3.
See [Dependencies](#dependencies) for details.

## Nocterm Foundation

[Nocterm](https://github.com/Norbert515/nocterm) is a Flutter-inspired TUI
framework for Dart. It uses the same three-tree architecture as Flutter:

```text
Component          Element              RenderObject
(declaration)  ->  (lifecycle)  ->      (layout + paint)
```

### Key component types

- **`StatelessComponent`** -- Immutable declaration, `build()` returns child
  tree. Rebuilt when parent provides new props.
- **`StatefulComponent`** -- Mutable state via `createState()`. Call
  `setState()` to schedule a rebuild. State persists across rebuilds.
- **`InheritedComponent`** -- Propagates data down the tree (equivalent to
  Flutter's `InheritedWidget`).

### Layout components

| Component | Purpose |
|-----------|---------|
| `Column` | Vertical flex layout |
| `Row` | Horizontal flex layout |
| `Expanded` | Fills remaining space in flex container |
| `Padding` | Adds padding around child |
| `SizedBox` | Fixed-size box |
| `ListView` | Scrollable list with `ScrollController` |
| `TextField` | Text input with cursor, selection |
| `Focusable` | Keyboard focus management |
| `MarkdownText` | Renders markdown with ANSI formatting |
| `Text` | Plain text with optional style |

### Rendering model

- **Differential rendering:** Only cells that changed since last frame are
  written to the terminal. Nocterm maintains a front buffer and a back buffer;
  on each frame it diffs them and emits only the changed ANSI sequences.
- **Event-driven frame scheduling:** Frames are not rendered on a fixed timer.
  Instead, `setState()` calls mark the tree dirty and schedule a frame. A
  frame-rate cap (default 30 fps) coalesces rapid state changes into a single
  render pass.
- **Terminal abstraction:** `Terminal` class wraps `TerminalBackend`
  (`StdioBackend` for Unix/macOS, `Win32AnsiStdin` on Windows). Handles cursor
  control, alternate screen, sixel graphics, clipboard via OSC 52.

### State management integrations

- **`nocterm_bloc`** -- BLoC pattern integration. `BlocBuilder<B, S>` rebuilds
  subtree when bloc state changes.
- **`nocterm_riverpod`** -- Riverpod integration for dependency injection and
  reactive state.

## Cow as Reference Architecture

[Cow](https://github.com/jolexxa/cow) is a local LLM chat client built on
nocterm. It demonstrates the exact patterns the Soliplex TUI needs.

### Agent event stream

Cow's `cow_brain` package defines a sealed `ModelOutput` hierarchy for
streaming events from the LLM:

| Event type | Description |
|-----------|-------------|
| `OutputTextDelta` | Incremental text token |
| `OutputReasoningDelta` | Hidden reasoning channel |
| `OutputToolCalls` | List of `ToolCall` objects |
| `OutputTokensGenerated` | Token count update |
| `OutputStepFinished` | Step completed with `FinishReason` |

These events drive the UI through a state machine. The Soliplex TUI maps
AG-UI events to this same pattern (see
[How It Maps to Soliplex](#how-it-maps-to-soliplex)).

### LogicBloc state machine

Cow uses a custom `LogicBlock` framework (in `packages/logic_blocks/`) rather
than `flutter_bloc`. Key concepts:

- **Blackboard pattern:** `ChatData` is a mutable shared data store accessible
  across all states. Holds `messages`, `activeTurn`, `executingTool`,
  `agentSettings`, `error`, `loadedModels`.
- **Sealed input/output events:** `ChatInput` (sealed) drives transitions;
  `ChatOutput` (sealed) drives side effects.
- **State types:** Each state handles inputs differently. Queue-based input
  processing prevents re-entrancy.

Key `ChatInput` events:

- `Submit` -- User sends a message
- `AgentEventReceived` -- Streaming event arrives from LLM
- `ExecutingToolCalls` -- Tool execution phase begins
- `ToolCallsComplete` -- Tool execution finished
- `TurnFinalized` -- Streaming complete
- `Cancel` -- User cancels current turn

Key `ChatOutput` events:

- `StateUpdated` -- Blackboard changed, UI re-derives
- `StartTurnRequested` -- Begin streaming for user message
- `ExecuteToolCallsRequested` -- Process tool calls from agent
- `TurnErrorLog` -- Capture failures for logging

### Chat phase state machine

```text
enum ChatPhase {
  idle,         // Awaiting user input
  loading,      // Model/resource loading
  reasoning,    // Hidden reasoning active
  responding,   // Text tokens streaming
  executingTool, // Tool calls in progress
  error,        // Failure state
}
```

### Chat page layout

Cow's chat page uses nocterm's flex layout:

```text
Column
  ├── Header        (room name, model info)
  ├── Expanded
  │   └── ChatBody  (scrollable ListView of ChatMessage items)
  ├── InputRow      (TextField + submit button)
  └── Footer        (keyboard shortcuts, status)
```

Messages use `MarkdownText` for rendering. Auto-scroll keeps the view at
the bottom during streaming via `ScrollController.scrollToEnd()`.

### Tool execution flow

1. LLM emits `OutputToolCalls` with one or more `ToolCall` objects
2. State machine transitions to `executingTool` phase
3. `CowBrain.sendToolResult()` executes tools (can be parallel)
4. Results sent back; LLM continues with tool results in context
5. State machine transitions back to `responding` or `idle`

The UI shows an indicator during tool execution ("Executing: tool_name").

### ChatMessage model

```dart
class ChatMessage {
  final String id;
  final String sender;  // "You" or "Cow"
  final String text;
  final DateTime timestamp;
  final ChatMessageKind kind; // user, assistant, system, reasoning, summary

  ChatMessage append(String delta); // For streaming token accumulation
  ChatMessage copyWithText(String text);
}
```

## How It Maps to Soliplex

The Soliplex TUI replaces cow's local llama.cpp backend with the Soliplex
AG-UI backend. The mapping is direct because both systems use an event stream
pattern.

### AG-UI events to nocterm rendering

| AG-UI event | Cow equivalent | TUI action |
|------------|----------------|------------|
| `TextMessageStartEvent` | `OutputTextDelta` (first) | Create new `ChatMessage`, begin streaming |
| `TextMessageContentEvent` | `OutputTextDelta` | Append delta to active message, rebuild `MarkdownText` |
| `TextMessageEndEvent` | `OutputStepFinished` | Finalize message, reset streaming state |
| `ThinkingTextMessageStartEvent` | `OutputReasoningDelta` (first) | Begin buffering reasoning text |
| `ThinkingTextMessageContentEvent` | `OutputReasoningDelta` | Append to reasoning pane |
| `ThinkingTextMessageEndEvent` | -- | Freeze reasoning display |
| `ToolCallStartEvent` | `OutputToolCalls` | Create `ToolCallInfo(status: streaming)` |
| `ToolCallArgsEvent` | -- | Accumulate argument deltas |
| `ToolCallEndEvent` | -- | Transition to `status: pending` |
| `RunStartedEvent` | -- | Set phase to `responding` |
| `RunFinishedEvent` | `OutputStepFinished` | Check for pending tools or complete |
| `RunErrorEvent` | -- | Set phase to `error`, display message |

### Core functions from soliplex_client

The TUI reuses the same pure-Dart building blocks as the CLI:

**`processEvent(Conversation, StreamingState, BaseEvent) -> EventProcessingResult`**

File: `packages/soliplex_client/lib/src/application/agui_event_processor.dart`

Pure function. Takes current state + incoming AG-UI event, returns updated
state. Handles the full event vocabulary: run lifecycle, text streaming, tool
call accumulation, state snapshots/deltas. The TUI feeds every SSE event
through this function, then derives UI state from the result.

**`ToolRegistry`**

File: `packages/soliplex_client/lib/src/application/tool_registry.dart`

Immutable registry of `ClientTool` objects. Each tool pairs an AG-UI `Tool`
definition (JSON Schema, sent to backend) with a `ToolExecutor` function
(runs locally). Key API:

```dart
ToolRegistry register(ClientTool tool);
ToolRegistry alias(String aliasName, String canonicalName);
Future<String> execute(ToolCallInfo toolCall);
List<Tool> get toolDefinitions;
```

**`convertToAgui(List<ChatMessage>)`**

File: `packages/soliplex_client/lib/src/api/agui_message_mapper.dart`

Converts domain `ChatMessage` list to AG-UI protocol `Message` list for
continuation runs. Handles `ToolCallMessage` to `AssistantMessage` +
`ToolMessage` conversion.

**`SoliplexApi`**

File: `packages/soliplex_client/lib/src/api/soliplex_api.dart`

REST client for backend operations: `getRooms()`, `createThread()`,
`createRun()`, `getThreadHistory()`, `submitFeedback()`. Built on pure-Dart
`HttpTransport`.

## Proposed UI Layout

### Primary layout (80+ columns)

```text
┌─────────────────────────────────────────────────────────────────────────┐
│ [Room: my-project]  [Thread: #4]                    [Connected] ●      │
├─────────────────────────────────────────────────────┬───────────────────┤
│                                                     │ Reasoning         │
│  You (14:32)                                        │                   │
│  Find the file that talks about the M6 spec         │ The user wants    │
│  and check GitHub for what checkin that landed       │ to find a file    │
│                                                     │ about M6 and      │
│  Assistant (14:32)                                   │ correlate it      │
│  The M6 specification is in                         │ with a GitHub     │
│  `docs/specs/m6-specification.md`. It covers        │ commit...         │
│  client-side tool calling.                          │                   │
│                                                     │                   │
│  The implementation landed in commit `abc1234`      │                   │
│  on 2025-01-15:                                     │                   │
│  > feat(tools): implement M6 client tool calling    │                   │
│                                                     │                   │
│                                                     │                   │
│                                                     │                   │
├─────────────────────────────────────────────────────┴───────────────────┤
│ Executing: fs_find, gh_search                              [2 tools]   │
├─────────────────────────────────────────────────────────────────────────┤
│ > Type a message...                                                    │
│                                                                        │
├─────────────────────────────────────────────────────────────────────────┤
│ Enter: Send  |  Ctrl+C: Cancel  |  Ctrl+R: Reasoning  |  Ctrl+Q: Quit │
└─────────────────────────────────────────────────────────────────────────┘
```

### Narrow layout (< 80 columns)

Reasoning pane collapses. Toggle with `Ctrl+R`.

```text
┌──────────────────────────────────────────┐
│ [my-project] [#4]            [Connected] │
├──────────────────────────────────────────┤
│                                          │
│  You (14:32)                             │
│  Find the M6 spec file...               │
│                                          │
│  Assistant (14:32)                       │
│  The M6 specification is in             │
│  `docs/specs/m6-specification.md`...    │
│                                          │
├──────────────────────────────────────────┤
│ Executing: fs_find              [1 tool] │
├──────────────────────────────────────────┤
│ > Type a message...                      │
├──────────────────────────────────────────┤
│ Enter | Ctrl+C | Ctrl+R | Ctrl+Q        │
└──────────────────────────────────────────┘
```

### Component tree

```dart
Column(
  children: [
    HeaderBar(room: room, thread: thread, connected: status),
    Expanded(
      child: Row(
        children: [
          Expanded(child: ChatBody(messages: messages, controller: scroll)),
          if (showReasoning && width >= 80)
            ReasoningPane(text: reasoningText),
        ],
      ),
    ),
    ToolStatusBar(tools: executingTools),
    InputRow(controller: inputController, onSubmit: onSubmit),
    FooterBar(shortcuts: shortcuts),
  ],
)
```

## State Management

The TUI uses a LogicBloc-style state machine (following cow's pattern) or
`nocterm_bloc` with a Cubit. Either approach works; the key requirement is
reactive UI rebuilds when state changes.

### ChatCubit (bloc approach)

```dart
class TuiChatCubit extends Cubit<TuiChatState> {
  TuiChatCubit({
    required SoliplexApi api,
    required ToolRegistry toolRegistry,
    required AgUiClient agUiClient,
  }) : super(const TuiChatState.idle());

  Future<void> sendMessage(String text) async { /* ... */ }
  void cancelRun() { /* ... */ }
  void toggleReasoning() { /* ... */ }
}
```

### State machine

```text
                        sendMessage()
          [Idle] ─────────────────────> [Streaming]
            ^                              │
            │                    ┌─────────┴──────────┐
            │                    │                     │
            │              no pending            pending tools
            │              tools                       │
            │                    │                     v
            │                    │            [ExecutingTools]
            │                    │                     │
            │                    │              tools complete
            │                    │                     │
            │                    │                     v
            │                    │            [Continuing]
            │                    │            (new run with results)
            │                    │                     │
            │                    └─────────────────────┘
            │                              │
            │                        RunFinished + no pending
            └──────────────────────────────┘

          [Error] <── RunErrorEvent from any state
            │
            └──── user dismisses or sends new message ──> [Idle]
```

### TuiChatState

```dart
sealed class TuiChatState {
  const TuiChatState();

  const factory TuiChatState.idle({
    required List<ChatMessage> messages,
  }) = IdleState;

  const factory TuiChatState.streaming({
    required List<ChatMessage> messages,
    required Conversation conversation,
    required StreamingState streamingState,
    String? reasoningText,
  }) = StreamingState;

  const factory TuiChatState.executingTools({
    required List<ChatMessage> messages,
    required Conversation conversation,
    required List<ToolCallInfo> pendingTools,
  }) = ExecutingToolsState;

  const factory TuiChatState.error({
    required List<ChatMessage> messages,
    required String errorMessage,
  }) = ErrorState;
}
```

### Event processing loop

The cubit's `sendMessage()` method drives the same tool-calling loop as the
CLI orchestrator, but emits state changes for the UI:

```dart
Future<void> sendMessage(String text) async {
  var conversation = /* build from history + new user message */;
  var depth = 0;

  while (depth < maxContinuationDepth) {
    emit(TuiChatState.streaming(
      messages: _deriveMessages(conversation),
      conversation: conversation,
      streamingState: const AwaitingText(),
    ));

    final eventStream = agUiClient.runAgent(threadId, input);
    var streaming = const AwaitingText() as StreamingState;

    await for (final event in eventStream) {
      final result = processEvent(conversation, streaming, event);
      conversation = result.conversation;
      streaming = result.streaming;

      // Emit on every event -- nocterm coalesces at 30fps
      emit(TuiChatState.streaming(
        messages: _deriveMessages(conversation),
        conversation: conversation,
        streamingState: streaming,
        reasoningText: _extractReasoning(streaming),
      ));
    }

    final pending = conversation.toolCalls
        .where((tc) => tc.status == ToolCallStatus.pending)
        .toList();

    if (pending.isEmpty) break;

    emit(TuiChatState.executingTools(
      messages: _deriveMessages(conversation),
      conversation: conversation,
      pendingTools: pending,
    ));

    // Execute tools locally
    for (final tc in pending) { /* ... */ }

    conversation = conversation
        .withAppendedMessage(ToolCallMessage.fromExecuted(pending))
        .copyWith(toolCalls: []);
    depth++;
  }

  emit(TuiChatState.idle(messages: _deriveMessages(conversation)));
}
```

## Streaming Rendering

### How tokens appear in real-time

1. AG-UI `TextMessageContentEvent` arrives with a text delta
2. `processEvent()` appends delta to the active message in `Conversation`
3. Cubit emits new `StreamingState` with updated messages
4. `BlocBuilder` marks the `ChatBody` component tree dirty
5. Nocterm's frame scheduler coalesces rapid emissions (30 fps cap)
6. On next frame, `MarkdownText` component rebuilds with accumulated text
7. Differential renderer writes only changed cells to the terminal

### Frame batching

Token arrivals can be faster than 30 fps (e.g., 100+ tokens/second). Nocterm's
event-driven frame scheduling naturally batches these:

```text
Token 1 ─── setState() ─── schedule frame ───┐
Token 2 ─── setState() ─── (already scheduled)│
Token 3 ─── setState() ─── (already scheduled)│
                                               ├── render frame (all 3 tokens)
                                               │
Token 4 ─── setState() ─── schedule frame ───┐
Token 5 ─── setState() ─── (already scheduled)│
                                               ├── render frame (2 tokens)
```

### Auto-scroll

A `ScrollController` attached to the chat `ListView` keeps the view at the
bottom during streaming:

```dart
void onStateChanged(TuiChatState state) {
  if (state is StreamingState) {
    scrollController.scrollToEnd();
  }
}
```

The controller supports `jumpTo()`, `scrollBy()`, `pageUp()`, `pageDown()`,
`scrollToEnd()`, and `ensureVisible()`.

## Proposed Tools

The TUI registers the same tool set as the CLI (0006):

| Tool | Description | Executor |
|------|------------|----------|
| `fs_list` | List files in a directory | `Directory(path).list()` |
| `fs_read` | Read file contents | `File(path).readAsString()` |
| `fs_find` | Find files by glob/regex | `Glob` from `package:glob` |
| `git_log` | Git commit history | `Process.run('git', ['log', ...])` |
| `git_diff` | Show diff for commit/range | `Process.run('git', ['diff', ...])` |
| `gh_search` | Search GitHub issues/PRs/commits | `Process.run('gh', ['search', ...])` |
| `gh_pr_view` | View PR details | `Process.run('gh', ['pr', 'view', ...])` |

See 0006-agentic-cli SPEC.md for full parameter schemas and executor details.

### Tool approval UX (TUI-specific)

Unlike the CLI (which may auto-approve), the TUI shows a confirmation dialog
before executing tools:

```text
┌────────────────────────────────────────┐
│ Tool Execution Request                 │
│                                        │
│ The assistant wants to run:            │
│   fs_read("docs/specs/m6-spec.md")    │
│   gh_search("M6 specification")       │
│                                        │
│ [Allow]  [Allow All]  [Deny]          │
└────────────────────────────────────────┘
```

- **Allow:** Execute this batch only
- **Allow All:** Auto-approve for remainder of this conversation
- **Deny:** Return error to model ("User denied tool execution")

This provides a safety net missing from headless CLI mode.

## Package Structure

```text
~/dev/soliplex_tui/
├── bin/
│   └── soliplex_tui.dart            # Entry point: parse args, run app
├── lib/
│   ├── src/
│   │   ├── app.dart                 # Root component, terminal setup
│   │   ├── state/
│   │   │   ├── tui_chat_cubit.dart  # Chat state machine (bloc)
│   │   │   └── tui_chat_state.dart  # State sealed classes
│   │   ├── components/
│   │   │   ├── chat_page.dart       # Main page layout
│   │   │   ├── header_bar.dart      # Room, thread, connection status
│   │   │   ├── chat_body.dart       # Scrollable message list
│   │   │   ├── message_item.dart    # Single message with MarkdownText
│   │   │   ├── reasoning_pane.dart  # Optional split pane for thinking
│   │   │   ├── tool_status_bar.dart # "Executing: fs_find, gh_search"
│   │   │   ├── input_row.dart       # Multiline TextField + submit
│   │   │   ├── footer_bar.dart      # Keyboard shortcuts
│   │   │   └── tool_approval.dart   # Confirmation dialog
│   │   └── tools/
│   │       ├── fs_tools.dart        # fs_list, fs_read, fs_find
│   │       ├── git_tools.dart       # git_log, git_diff
│   │       └── gh_tools.dart        # gh_search, gh_pr_view
│   └── soliplex_tui.dart            # Public API barrel file
├── test/
│   ├── state/
│   │   └── tui_chat_cubit_test.dart
│   ├── components/
│   │   ├── chat_body_test.dart
│   │   ├── message_item_test.dart
│   │   └── tool_approval_test.dart
│   └── tools/
│       ├── fs_tools_test.dart
│       ├── git_tools_test.dart
│       └── gh_tools_test.dart
├── pubspec.yaml
├── analysis_options.yaml
└── CHANGELOG.md
```

### pubspec.yaml (key dependencies)

```yaml
name: soliplex_tui
environment:
  sdk: ^3.6.0

dependencies:
  soliplex_client:
    path: ../soliplex-flutter-charting/packages/soliplex_client
  ag_ui:
    path: ../soliplex-flutter-charting/packages/ag_ui
  nocterm: ^0.x.0
  nocterm_bloc: ^0.x.0
  bloc: ^8.0.0
  args: ^2.5.0
  glob: ^2.1.0

dev_dependencies:
  test: ^1.25.0
  mocktail: ^1.0.0
  bloc_test: ^9.0.0
```

## Relationship to 0006 (CLI)

### Shared components (pure Dart)

Both the CLI and TUI depend on `soliplex_client` and share:

- `processEvent()` -- Same pure function for event processing
- `ToolRegistry` -- Same immutable tool registry
- `convertToAgui()` -- Same message mapper for continuation runs
- `SoliplexApi` -- Same REST client
- `DartHttpClient` / `HttpTransport` -- Same HTTP stack
- Circuit breaker (`maxContinuationDepth = 10`)
- Per-tool error isolation (try/catch per tool)

### What differs

| Layer | CLI (0006) | TUI (0007) |
|-------|-----------|-----------|
| **Entry point** | `soliplex_cli.dart` | `soliplex_tui.dart` |
| **Orchestration** | `CliOrchestrator` (async method) | `TuiChatCubit` (bloc) |
| **State** | Local variables in `while` loop | Sealed `TuiChatState` emissions |
| **Rendering** | `stdout.writeln()` | Nocterm component tree |
| **Text display** | Plain text / ANSI | `MarkdownText` component |
| **Scrolling** | Terminal scroll buffer | `ListView` + `ScrollController` |
| **Reasoning** | Not displayed | Split pane with `ReasoningPane` |
| **Tool approval** | Flag-based (`--auto-approve`) | Interactive dialog |
| **Concurrency** | Single-threaded REPL | Single-threaded (can extend) |

### Potential shared package: `soliplex_tools`

Both CLI and TUI register identical tool definitions (`fs_list`, `fs_read`,
etc.). A shared `soliplex_tools` package could provide:

```dart
// packages/soliplex_tools/lib/soliplex_tools.dart
ToolRegistry buildDefaultToolRegistry() {
  return const ToolRegistry()
      .register(fsListTool)
      .register(fsReadTool)
      .register(fsFindTool)
      .register(gitLogTool)
      .register(gitDiffTool)
      .register(ghSearchTool)
      .register(ghPrViewTool);
}
```

This avoids duplicating tool definitions across two packages. The shared
package depends only on `soliplex_client` (pure Dart) and `dart:io`.

## Dependencies

### M6 slices 1-3 must land first

| Slice | What the TUI needs | Reference |
|-------|--------------------|-----------|
| **Slice 1** | `ToolCallArgsEvent` accumulation in `processEvent()`. Without this, tool call arguments are lost during event processing. | `docs/planning/slice-1-tool-registry-provider.md` |
| **Slice 2** | Mock LLM harness (`buildMockEventStream`, `FakeAgUiClient`). Required for testing `TuiChatCubit` without a live backend. | `docs/planning/slice-2-mock-llm-harness.md` |
| **Slice 3** | `ToolCallMessage.fromExecuted()` domain helper for synthesizing tool result messages. The `ExecutingToolsState` pattern is the model for the TUI's own state. | `docs/planning/slice-3-orchestration.md` |

### Nocterm packages

| Package | Purpose | Status |
|---------|---------|--------|
| `nocterm` | Core TUI framework | Required |
| `nocterm_bloc` | BLoC integration for nocterm | Required |
| `bloc` | BLoC state management | Required |

### Other dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| `soliplex_client` | Ready | Pure Dart, all needed APIs exist |
| `ag_ui` | Ready | AG-UI protocol types and event decoder |
| `dart:io` | Ready | `Process.run`, `File`, `Directory` |
| `package:args` | Add | CLI argument parsing |
| `package:glob` | Add | For `fs_find` tool |
| `gh` CLI | Runtime | Must be installed for `gh_*` tools |
| `git` CLI | Runtime | Must be available on PATH for `git_*` tools |

## Open Questions

### Theming

- Should the TUI support configurable color themes?
- Nocterm supports foreground/background color via ANSI. Should we ship a
  default dark theme and allow override via config file?
- Should syntax highlighting in code blocks use a specific color scheme?

### Reasoning pane

- **Always visible or toggle?** Cow shows reasoning inline. The TUI could use
  a split pane (shown in mockup) or inline collapsible sections.
- **Minimum width:** At what terminal width does the reasoning pane collapse?
  Proposed: 80 columns.
- **Buffered thinking:** AG-UI `ThinkingTextMessage*` events carry reasoning.
  Should this be shown live (streaming) or only after the turn completes?

### Tool approval UX

- **Default mode:** Should the TUI default to confirming each tool batch, or
  auto-approve like the CLI?
- **Trust levels:** Could tools be categorized as safe (fs_read) vs dangerous
  (hypothetical fs_write) with different approval defaults?
- **Keyboard shortcut:** Should `Enter` default to "Allow" in the dialog?

### Multi-thread support

- **Thread switching:** Should the TUI support switching between threads
  within a room, or is each session single-thread?
- **Thread picker:** Interactive list of threads at startup, or CLI flag?

### History replay

- **On connect:** Should the TUI replay thread history on startup using
  `SoliplexApi.getThreadHistory()`?
- **Scroll position:** Start at bottom (latest) or top (oldest)?

### Feedback

- **Thumbs up/down:** Should the TUI support the feedback flow (0005) via
  keyboard shortcuts on messages? e.g., navigate to a message and press `+`
  or `-`.

### Testing strategy

- **Nocterm test utilities:** Does nocterm provide a test harness for component
  testing (equivalent to Flutter's `WidgetTester`)?
- **Cubit testing:** `bloc_test` works with `TuiChatCubit` directly (no UI).
- **Integration tests:** Mock event streams via `FakeAgUiClient` from M6
  slice 2.
