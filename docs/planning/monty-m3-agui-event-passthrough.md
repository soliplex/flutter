# M3: AG-UI Event Passthrough

**Roadmap:** [monty-integration-roadmap.md](monty-integration-roadmap.md)
**Depends on:** M1 (Registry + Introspection)
**Can parallelize with:** M2

---

## Problem

`execute_python` flattens the bridge event stream to a plain
string. All intermediate feedback (steps, tool calls, print output) is
discarded.

## Delivers

Chat UI shows real-time Python execution feedback.

## New Files

| File | What |
|------|------|
| `packages/soliplex_client/lib/src/domain/tool_execution_observer.dart` | `ToolExecutionObserver` interface — `onToolEvent(toolCallId, BaseEvent)` |

## Modified

| File | Change |
|------|--------|
| `lib/core/providers/api_provider.dart` | execute_python executor forwards bridge events through observer via closure capture |
| `lib/core/providers/active_run_notifier.dart` | Provides observer in `_executeToolsAndContinue`. Maps sub-events to state updates |
| `lib/features/chat/widgets/status_indicator.dart` | Shows Python step names during execution |

## Design

- Observer is **opt-in** — `ClientTool.executor` signature unchanged
- Passed via **closure capture** (not Zone values — those are fragile)
- execute_python still returns `Future<String>` for the LLM
- If jank appears from rapid events, add frame batching then (not now)
- No platform-specific code needed — pure Dart + Flutter

## Done When

- Status shows "Running Python... calling search_documents..."
- Print output streams during execution (not batched until end)
- Tool call results visible as they complete
