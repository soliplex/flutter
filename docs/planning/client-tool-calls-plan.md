# Client-Side Tool Calling -- Milestone Plan

> 4 stacked PRs. Each slice builds on the previous. After each slice, Codex
> and Gemini review before work begins on the next.

## Stacked PR Strategy

```text
main
 └── feat/client-tool-calling-v3           (cherry-picked base: ToolRegistry, streaming enum, mapper fixes)
      └── feat/client-tool-calling-v3/slice-1   PR #? -> main
           └── feat/client-tool-calling-v3/slice-2   PR #? -> slice-1
                └── feat/client-tool-calling-v3/slice-3   PR #? -> slice-2
                     └── feat/client-tool-calling-v3/slice-4   PR #? -> slice-3
```

Each PR shows only the diff for its slice. Merges happen bottom-up:
slice-1 merges to main first, then slice-2 retargets to main, etc.

---

## Milestones

### Slice 1: Wire ToolRegistry Provider + Event Processor Args Accumulation

- **Spec:** [slice-1-tool-registry-provider.md](slice-1-tool-registry-provider.md)
- **Branch:** `feat/client-tool-calling-v3/slice-1`
- **PR target:** `main`

#### Gates

**Implementation:**

- [ ] Implementation complete
- [ ] Dartdoc on all public APIs (`toolRegistryProvider`, new event processor branches)

**Code quality (autonomous):**

- [ ] `dart format .` -- no changes
- [ ] `flutter analyze --fatal-infos` -- 0 issues (errors, warnings, AND infos)
- [ ] No `// ignore:` directives added

**Tests (autonomous):**

- [ ] `dart test packages/soliplex_client/` -- all pass
- [ ] `flutter test` -- all pass
- [ ] New test coverage >= 85% on changed files

**AI review (gate -- must pass before next slice):**

- [ ] **Codex review** of PR diff -- event processor state transitions correctness
- [ ] **Gemini `read_files`** (`gemini-3.1-pro-preview`) of changed files -- architecture alignment, test gaps
- [ ] All review feedback addressed

#### Autonomous test commands

```bash
dart test packages/soliplex_client/test/application/agui_event_processor_test.dart
dart test packages/soliplex_client/
flutter test
```

---

### Slice 2: Mock LLM Harness + Secret-Number Integration Tests

- **Spec:** [slice-2-mock-llm-harness.md](slice-2-mock-llm-harness.md)
- **Branch:** `feat/client-tool-calling-v3/slice-2`
- **PR target:** `feat/client-tool-calling-v3/slice-1`
- **Depends on:** Slice 1

#### Gates

**Implementation:**

- [ ] Implementation complete
- [ ] Dartdoc on all public APIs (`buildMockEventStream`, `FakeAgUiClient`, `ToolCallMessage.fromExecuted`)

**Code quality (autonomous):**

- [ ] `dart format .` -- no changes
- [ ] `flutter analyze --fatal-infos` -- 0 issues
- [ ] No `// ignore:` directives added

**Tests (autonomous):**

- [ ] `flutter test` -- all pass
- [ ] Secret-number happy path passes with zero network calls
- [ ] `ToolCallMessage.fromExecuted` domain helper tested
- [ ] New test coverage >= 85% on changed files

**AI review (gate -- must pass before next slice):**

- [ ] **Codex review** of PR diff -- mock fidelity vs real AG-UI protocol
- [ ] **Gemini `read_files`** (`gemini-3.1-pro-preview`) of changed files -- harness ergonomics, missing edge cases
- [ ] All review feedback addressed

#### Autonomous test commands

```bash
flutter test test/core/providers/tool_call_integration_test.dart
dart test packages/soliplex_client/test/domain/chat_message_test.dart
flutter test
```

---

### Slice 3: Tool Execution Orchestration in ActiveRunNotifier

- **Spec:** [slice-3-orchestration.md](slice-3-orchestration.md)
- **Branch:** `feat/client-tool-calling-v3/slice-3`
- **PR target:** `feat/client-tool-calling-v3/slice-2`
- **Depends on:** Slice 1 + Slice 2

#### Gates

**Implementation:**

- [ ] Implementation complete
- [ ] Dartdoc on all public APIs (`ExecutingToolsState`, `RunContinued`, `replaceRun`, `_maxContinuationDepth`)

**Code quality (autonomous):**

- [ ] `dart format .` -- no changes
- [ ] `flutter analyze --fatal-infos` -- 0 issues
- [ ] No `// ignore:` directives added

**Tests (autonomous):**

- [ ] `flutter test` -- all pass
- [ ] All 20 orchestration test cases pass (see slice spec)
- [ ] Safety invariant verified: no path leaves `ExecutingToolsState` as terminal
- [ ] Circuit breaker prevents infinite multi-hop loops
- [ ] `_abortToCompleted` clears pending toolCalls
- [ ] New test coverage >= 85% on changed files

**AI review (gate -- must pass before next slice):**

- [ ] **Codex review** of PR diff -- safety invariant, concurrency, CAS semantics
- [ ] **Gemini `read_files`** (`gemini-3.1-pro-preview`) of changed files -- orchestration completeness, edge cases
- [ ] All review feedback addressed

#### Autonomous test commands

```bash
flutter test test/core/providers/active_run_notifier_tool_call_test.dart
flutter test test/core/models/active_run_state_test.dart
flutter test test/core/services/run_registry_test.dart
flutter test
```

---

### Slice 4: Cleanup Stale Branches and PRs

- **Spec:** [slice-4-cleanup.md](slice-4-cleanup.md)
- **Branch:** `feat/client-tool-calling-v3/slice-4`
- **PR target:** `feat/client-tool-calling-v3/slice-3`
- **Depends on:** Slices 1-3 merged

#### Gates

**Implementation:**

- [ ] PRs #291, #294 closed with rationale
- [ ] PR #290 reviewed (keep or close)
- [ ] Stale remote branches deleted

**Code quality (autonomous):**

- [ ] `dart format .` -- no changes
- [ ] `flutter analyze --fatal-infos` -- 0 issues
- [ ] `flutter test` -- full suite passes

**AI review (gate -- must pass before merge):**

- [ ] **Codex review** of PR closure comments -- accuracy
- [ ] **Gemini `read_files`** (`gemini-3.1-pro-preview`) of closed PR diffs -- no useful work lost
- [ ] All review feedback addressed

#### Autonomous test commands

```bash
flutter test
dart test packages/soliplex_client/
flutter analyze --fatal-infos
```

---

## Workflow

```text
For each slice:
  1. Branch from previous slice
  2. Implement (code + tests)
  3. Run autonomous tests (commands above)
  4. Run format + analyze
  5. Commit + push + create PR
  6. Codex review (critical eye on correctness)
  7. Gemini review (`gemini-3.1-pro-preview`, architecture + coverage)
  8. Address feedback, re-run tests
  9. ✅ Merge only after both reviews pass
  10. Next slice branches from merged result
```

## Testing Philosophy

**Autonomous-first.** Every test runs without:

- Live backend / API keys
- Network connectivity
- Human interaction
- External LLM calls

The mock LLM harness (Slice 2) is the cornerstone. It provides deterministic
AG-UI event streams that exercise the full pipeline: event processing ->
tool accumulation -> execution -> continuation -> final response.

**Test pyramid:**

| Level | Location | Runner | What it proves |
|-------|----------|--------|---------------|
| Unit | `packages/soliplex_client/test/` | `dart test` | Event processor, ToolRegistry, mapper, domain models |
| Provider | `test/core/providers/` | `flutter test` | Notifier orchestration, state transitions, safety checks |
| Model | `test/core/models/` | `flutter test` | ActiveRunState subclasses, lifecycle events |
| Service | `test/core/services/` | `flutter test` | RunRegistry.replaceRun CAS semantics |
| Widget | `test/features/` | `flutter test` | StatusIndicator display for ExecutingToolsState |

**Coverage target:** 85%+ on new code (project standard).

**CI enforcement:** All tests run in randomized order via
`.github/workflows/flutter.yaml` with seed reporting for flake reproduction.

---

## Dependencies

**`fix/scroll` branch** must land before or alongside Slice 3. The new
scroll system (`ScrollToMessageSession` + `ScrollButtonController`) handles
`RunContinued` implicitly -- `_lastScrolledId` prevents re-scroll on
continuation runs, and `targetScrollOffset` persists so the dynamic spacer
shrinks correctly. No explicit tool-calling scroll support needed.

## Reference

- [Full orchestration design](client-tool-calling-v3-reference.md) -- state transitions,
  safety checks, concurrency analysis, edge cases
- [ToolRegistry](../../packages/soliplex_client/lib/src/application/tool_registry.dart) --
  already on v3 base branch
- [agui_event_processor](../../packages/soliplex_client/lib/src/application/agui_event_processor.dart) --
  current event processing logic
- [ActiveRunNotifier](../../lib/core/providers/active_run_notifier.dart) --
  orchestration target for Slice 3

## Supersedes

| PR | Title | Replaced by |
|----|-------|-------------|
| #282 | feat/client-tool-calling-v2 | This plan (v3) |
| #291 | test/patrol-tool-calling | Slice 2 (mock LLM tests) |
| #294 | refactor/notifier-stream-setup | Slice 3 (`_establishSubscription`) |
| #290 | refactor/notifier-test-container | Independent -- reviewed in Slice 4 |
