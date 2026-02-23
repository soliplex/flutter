# Slice 1: Wire ToolRegistry Provider + Event Processor Args Accumulation

**Branch:** `feat/client-tool-calling-v3/slice-1` (stacked on `feat/client-tool-calling-v3`)
**PR:** `feat/client-tool-calling-v3/slice-1` -> `main`

---

## Goal

ToolRegistry is available app-wide with a clear registration path. ToolCallArgs
events accumulate arguments on ToolCallInfo. ToolCallEnd transitions status to
`pending` (not removal). No execution yet -- that is Slice 3.

## Deliverable

White-label apps can define and inject custom tools via
`toolRegistryProvider.overrideWithValue(...)`. The UI accurately shows
"Calling: [tool_name]" while the LLM streams tool requests (existing
`ToolCallActivity` support). Tool arguments are correctly accumulated
across multiple `ToolCallArgsEvent` deltas.

---

## Implementation

### 1. Add `toolRegistryProvider`

**File:** `lib/core/providers/api_provider.dart`

```dart
final toolRegistryProvider = Provider<ToolRegistry>((ref) {
  // Default: empty registry. Override in ProviderScope for real tools.
  return const ToolRegistry();
});
```

### 2. Document override pattern

**File:** `lib/run_soliplex_app.dart` (docstring only, no actual tools registered)

Follows the existing `shellConfigProvider`, `preloadedPrefsProvider` pattern
at `lib/run_soliplex_app.dart:107-117`:

```dart
// In ProviderScope.overrides:
toolRegistryProvider.overrideWithValue(
  const ToolRegistry()
      .register(someClientTool)
      .register(anotherClientTool),
),
```

### 3. Event processor changes

**File:** `packages/soliplex_client/lib/src/application/agui_event_processor.dart`

| Event | Current behavior | New behavior |
|-------|-----------------|--------------|
| `ToolCallStartEvent` | Creates `ToolCallInfo(status: pending)` | Creates `ToolCallInfo(status: streaming)` |
| `ToolCallArgsEvent` | Not handled | Find matching `ToolCallInfo` by `toolCallId`, append `delta` to `arguments` |
| `ToolCallEndEvent` | Removes tool from activity tracking | Transition matching `ToolCallInfo` to `status: pending`; keep in `conversation.toolCalls` |

---

## Files Changed

| File | Change |
|------|--------|
| `lib/core/providers/api_provider.dart` | Add `toolRegistryProvider` (empty default) |
| `lib/run_soliplex_app.dart` | Add docstring showing override pattern |
| `packages/soliplex_client/lib/src/application/agui_event_processor.dart` | ToolCallStart -> streaming, ToolCallArgs accumulation, ToolCallEnd -> pending |
| `packages/soliplex_client/test/application/agui_event_processor_test.dart` | New test cases (see Testing below) |

---

## Testing

All tests in this slice are **pure Dart unit tests** in `packages/soliplex_client/`.
They run with `dart test` (no Flutter SDK, no network, no external services).

### Autonomous test commands

```bash
# Run only Slice 1 tests (fast, targeted)
dart test packages/soliplex_client/test/application/agui_event_processor_test.dart

# Run full soliplex_client suite (verify no regressions)
dart test packages/soliplex_client/

# Existing tool_registry tests (already committed on v3 base)
dart test packages/soliplex_client/test/application/tool_registry_test.dart
```

### Test cases for `agui_event_processor_test.dart`

#### Args accumulation

| # | Test | Input events | Assert |
|---|------|-------------|--------|
| 1 | Single delta fills arguments | `ToolCallStart(id: tc-1)` -> `ToolCallArgs(id: tc-1, delta: '{"q":"test"}')` | `toolCalls[0].arguments == '{"q":"test"}'` |
| 2 | Multiple deltas concatenate | `ToolCallArgs(delta: '{"q":')` -> `ToolCallArgs(delta: ' "test"}')` | `toolCalls[0].arguments == '{"q": "test"}'` |
| 3 | Zero-arg tool (no ToolCallArgs) | `ToolCallStart(id: tc-1)` -> `ToolCallEnd(id: tc-1)` | `toolCalls[0].arguments == ''` (mapper normalizes to `'{}'`) |

#### Status transitions

| # | Test | Input events | Assert |
|---|------|-------------|--------|
| 4 | ToolCallStart sets streaming | `ToolCallStart(id: tc-1)` | `toolCalls[0].status == ToolCallStatus.streaming` |
| 5 | ToolCallEnd transitions to pending | `ToolCallStart` -> `ToolCallArgs` -> `ToolCallEnd` | `toolCalls[0].status == ToolCallStatus.pending` |
| 6 | Multiple tools accumulate independently | Start(A) -> Args(A) -> End(A) -> Start(B) -> Args(B) -> End(B) | `toolCalls.length == 2`, both `pending`, correct args each |

#### Regression (existing behavior preserved)

| # | Test | Verify |
|---|------|--------|
| 7 | ToolCallActivity still tracks tool names | `ToolCallStart` -> activity has tool name in `allToolNames` |
| 8 | ToolCallEnd still removes from activity | After `ToolCallEnd`, activity no longer contains that tool name |
| 9 | Text + tool calls coexist | `TextStart` -> `TextContent` -> `TextEnd` -> `ToolCallStart` -> ... -> both message and toolCalls present |

### Test for `toolRegistryProvider`

In `test/core/providers/api_provider_test.dart` (append to existing file):

```dart
group('toolRegistryProvider', () {
  test('returns empty ToolRegistry by default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = container.read(toolRegistryProvider);
    expect(registry.toolDefinitions, isEmpty);
  });

  test('can be overridden with tools', () {
    final registry = const ToolRegistry().register(
      ClientTool(
        name: 'test_tool',
        description: 'A test tool',
        parameters: {},
        executor: (args) async => 'result',
      ),
    );
    final container = ProviderContainer(
      overrides: [toolRegistryProvider.overrideWithValue(registry)],
    );
    addTearDown(container.dispose);
    expect(container.read(toolRegistryProvider).toolDefinitions, hasLength(1));
  });
});
```

---

## Acceptance Criteria

- [ ] `dart format .` -- no changes
- [ ] `flutter analyze --fatal-infos` -- 0 issues
- [ ] `dart test packages/soliplex_client/` -- all pass
- [ ] `flutter test` -- all pass (app-level)
- [ ] `toolRegistryProvider` exists and returns empty `ToolRegistry` by default
- [ ] `ToolCallStart` creates `ToolCallInfo` with `status: streaming`
- [ ] `ToolCallArgs` appends delta to matching `ToolCallInfo.arguments`
- [ ] `ToolCallEnd` transitions to `status: pending` (tool stays in `conversation.toolCalls`)
- [ ] Zero-arg tools have empty arguments (mapper already normalizes to `'{}'`)
- [ ] Existing `ToolCallActivity` still tracks tool names for UI

---

## Review Gate

After implementation, before merging:

1. **Codex review** -- correctness of event processor state transitions
2. **Gemini review** (`gemini-3.1-pro-preview`) -- architecture alignment, test coverage gaps
3. Both reviews addressed before moving to Slice 2
