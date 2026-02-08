# Client-Side Tool Calling for Patrol Room

**Status:** plan
**Depends on:** PR #83 (`feat/client-tool-calling`), Phase E spec

## Problem

The Patrol Test Runner room (`example/rooms/patrol/`) works end-to-end:
agent receives messages, calls `patrol_run`, reports results. But
`patrol test` fails when spawned from the Soliplex Python server because
it runs headless — no WindowServer access means xcodebuild exits with
code 65 ("no supported run destinations").

## Solution: Client-Side Tool Execution

Move `patrol_run` execution from the server to the Flutter client.
The server orchestrates (LLM decides to call the tool), the client
executes (has GUI access, correct paths, and environment).

PR #83 adds the infrastructure:

- **ToolRegistry** — register client-side tool definitions and executors
- **ActiveRunNotifier** — detects pending tool calls, executes locally
- **agui_message_mapper** — sends tool results back to server
- **hasExecutor()** filter — skips server-side tools, only runs
  client-registered tools

## Architecture

```text
User: "Run the smoke test"
        │
        ▼
┌──────────────────────┐
│  Soliplex Backend     │
│  (pydantic_ai agent)  │
│                        │
│  Agent decides:        │
│  call patrol_run(      │
│    target: smoke_test) │
└──────────┬─────────────┘
           │ AG-UI SSE stream
           │ TOOL_CALL_START → TOOL_CALL_ARGS → TOOL_CALL_END
           ▼
┌──────────────────────┐
│  Flutter Client       │
│  (ActiveRunNotifier)  │
│                        │
│  ToolRegistry.has(     │
│    "patrol_run") ✓     │
│                        │
│  Execute locally:      │
│  Process.run("patrol   │
│    test --device macos │
│    --target ...")       │
│                        │
│  Stream STATE_DELTA    │
│  events with stdout    │
│  lines as they arrive  │
└──────────┬─────────────┘
           │ POST tool result back
           ▼
┌──────────────────────┐
│  Agent continues      │
│  "All tests PASSED"   │
└──────────────────────┘
```

## Implementation Steps

### 1. Merge PR #83 into main

The client-tool-calling branch needs to be rebased onto current main
(it's behind by ~20 commits). Resolve conflicts in:

- `active_run_notifier.dart` (logging changes, state shape)
- `chat_input.dart` (suggestion chips, document picker)
- `agui_event_processor.dart` (ToolCallActivity)
- `pubspec.yaml` (patrol deps, soliplex_logging)

### 2. Register `patrol_run` as a client tool

```dart
// In a provider or app initialization
final toolRegistry = ref.read(toolRegistryProvider);
toolRegistry.register(
  ToolDefinition(
    name: 'patrol_run',
    description: 'Run a Patrol E2E test locally',
    parameters: {
      'target': ToolParameter(type: 'string', required: true),
      'backend_url': ToolParameter(type: 'string', required: false),
    },
    executor: (args) async {
      final target = args['target'] as String;
      final backendUrl = args['backend_url'] as String?
          ?? 'http://localhost:8000';

      // Validate target
      const allowed = {
        'smoke_test.dart',
        'live_chat_test.dart',
        'settings_test.dart',
        'oidc_test.dart',
      };
      if (!allowed.contains(target)) {
        return 'Invalid target. Allowed: ${allowed.join(', ')}';
      }

      final result = await Process.run(
        patrolCliPath,
        ['test', '--device', 'macos',
         '--target', 'integration_test/$target',
         '--dart-define', 'SOLIPLEX_BACKEND_URL=$backendUrl'],
        workingDirectory: flutterProjectPath,
      );

      final output = result.stdout as String;
      if (result.exitCode == 0) {
        return 'PASSED\n\n${output.substring(output.length - 500)}';
      }
      return 'FAILED (exit ${result.exitCode})\n\n'
             '${output.substring(output.length - 1000)}';
    },
  ),
);
```

### 3. Update room config — declare tool as client-side

The room config needs a way to tell the server that `patrol_run` is
a client-side tool (server should emit the tool call event, not
execute it). Options:

- **Option A:** Server-side tool stub that raises "client-side only"
- **Option B:** Room config `client_tools:` section (new feature)
- **Option C:** Tool definition with `execution: client` flag

Option A works today with no server changes — register a dummy
`patrol_run` tool on the server that returns an instruction string,
and the client intercepts it before the server executes.

Option B is cleaner but requires server-side changes to room config
parsing.

### 4. Stream stdout via STATE_DELTA

Instead of `Process.run` (blocks until completion), use `Process.start`
and stream stdout line-by-line:

```dart
final process = await Process.start(patrolCliPath, args);
await for (final line in process.stdout
    .transform(utf8.decoder)
    .transform(const LineSplitter())) {
  // Push state delta to AG-UI stream
  emitStateDelta({
    'patrol': {
      'status': 'running',
      'output_tail': line,
    },
  });
}
```

This gives real-time test output in the chat UI while patrol runs.

### 5. Add patrol output widget

The Flutter client needs a widget that renders `state.patrol` updates.
Could be a collapsible log viewer in the chat thread, similar to the
"Thinking" section.

## Benefits Over Server-Side

| Concern | Server-side | Client-side |
|---------|-------------|-------------|
| GUI access | needs hacks | native |
| Path config | env vars | client knows its env |
| Streaming | blocked until done | line-by-line |
| Platform | macOS-specific hacks | wherever client runs |
| Security | server runs commands | user's machine |

## Open Questions

1. **Tool stub vs client_tools config**: Which approach for telling
   the server "don't execute this, let the client handle it"?
2. **Process path discovery**: How does the Flutter client find the
   `patrol` CLI path? Env var, settings page, or auto-detect from
   `~/.pub-cache/bin/`?
3. **Concurrent test prevention**: Should the client block a second
   `patrol_run` while one is already executing?
4. **Dev-mode guard**: Client-side tool registration should only
   happen when `SOLIPLEX_DEV_MODE=true` to prevent the patrol tool
   from appearing in production builds.
