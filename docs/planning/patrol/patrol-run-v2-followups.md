# patrol_run Tool — v2 Follow-ups

Gaps identified during v1 implementation review (cross-validated by
Gemini gemini-3-pro against `client-tools-plan.md` and
`phase-e-agent-loop.md`).

## Status

v1 is merged and working: tool definition, registry wiring, allowlist
security, unit tests all pass. These items are enhancements for v2.

## 1. Streaming Output (Process.start)

**Gap:** `patrol_run_tool.dart` uses `Process.run` (blocking). The plan
spec'd `Process.start` with line-by-line streaming via `STATE_DELTA` so
the chat UI shows live test progress.

**Impact:** UI shows no feedback for the entire test duration (potentially
minutes). May hit the 600s AG-UI timeout on longer test suites.

**Fix:** Refactor executor to use `Process.start`, pipe stdout/stderr
lines as intermediate state deltas through `ActiveRunNotifier`. Requires
either changing `ToolExecutor` signature to support streaming callbacks
or adding a side-channel mechanism.

**Files:**

- `packages/soliplex_client/lib/src/application/tools/patrol_run_tool.dart`
- `packages/soliplex_client/lib/src/application/tool_registry.dart`
  (signature change if streaming callback added)
- `lib/core/providers/active_run_notifier.dart`
  (`_executeToolsAndContinue` needs streaming support)

## 2. Config via --dart-define (not env var)

**Gap:** Executor passes `backend_url` as a process environment variable
(`environment: {'BACKEND_URL': backendUrl}`). Flutter apps read
compile-time config from `String.fromEnvironment`, which requires
`--dart-define`.

**Impact:** The backend URL parameter is silently ignored — the launched
test always uses its compiled-in default.

**Fix:** Change the `Process.run` arguments to include
`'--dart-define', 'SOLIPLEX_BACKEND_URL=$backendUrl'` instead of using
the `environment` map.

**Files:**

- `packages/soliplex_client/lib/src/application/tools/patrol_run_tool.dart`

## 3. Patrol CLI Path Resolution

**Gap:** Executor calls bare `'patrol'` which relies on shell `PATH`.
macOS GUI apps launched via Xcode or Finder do not inherit the user's
shell PATH, so `~/.pub-cache/bin/patrol` is not found.

**Impact:** Tool fails with "command not found" when the app is launched
outside a terminal session.

**Fix options (pick one):**

- Resolve `Platform.environment['HOME']/.pub-cache/bin/patrol` as
  fallback when bare `patrol` is not found
- Accept an optional `patrol_path` parameter in the tool schema
- Read from an environment variable (`PATROL_CLI_PATH`)

**Files:**

- `packages/soliplex_client/lib/src/application/tools/patrol_run_tool.dart`

## Priority

| Item | Severity | Effort |
|------|----------|--------|
| Streaming output | High (UX) | Medium |
| dart-define config | Medium (correctness) | Low |
| PATH resolution | Medium (reliability) | Low |

Streaming is the highest priority since it directly affects the Phase E
agent-in-the-loop experience — the agent needs incremental output to
diagnose failures in real time.
