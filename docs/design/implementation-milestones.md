# soliplex_agent — Implementation Milestones

## Execution Model

- **Claude Code (Opus)** — main implementer, writes code, runs tests, commits
- **Gemini 3.1 Pro (read_files)** — reviews diffs, validates against design docs
- **Codex** — parallel worker for isolated tasks (test scaffolding, boilerplate)

**Constraint:** After every milestone the deliverable is fully working.
Green build = `dart analyze` + `dcm analyze` + `dart test` in the new
package, plus `flutter analyze --fatal-infos` + `flutter test` unchanged
in the app. DCM is a separate CLI (`dcm analyze packages/soliplex_agent`)
enforcing strict thresholds from `dcm_options.yaml`.

**Approach:** Greenfield. We are NOT refactoring the existing app. The
new package lives side-by-side. Existing `ActiveRunNotifier`, providers,
Monty bridge code — all untouched.

## Quality Tooling — Strict from Day One

The `soliplex_agent` package starts at the strictest quality bar.
No relaxed "Stage 1" — we enforce everything immediately because
there is no legacy code to migrate.

### Static Analysis

- **`very_good_analysis`** — included via `analysis_options.yaml`
- **DCM** — included via `dcm_options.yaml` with tight thresholds:

| Metric | Threshold | Rationale |
|--------|-----------|-----------|
| Cyclomatic complexity | **10** | Forces small, testable methods |
| Lines of code | **40** | No god-methods |
| Number of parameters | **4** | Constructor injection keeps this low |
| Maximum nesting level | **3** | Extract or early-return |

DCM rules enabled from the start (not just metrics):
- `avoid-nested-conditional-expressions`
- `avoid-returning-widgets` (N/A for pure Dart, but future-proof)
- `prefer-correct-identifier-length`
- `prefer-moving-to-variable`

### Formatting

- `dart format .` — zero diff required before commit

### Review Workflow

Every milestone is reviewed before merge using `tool/milestone_review.sh`:

```bash
# After completing milestone work:
bash tool/milestone_review.sh M1                        # full: tests + analyze + metrics
bash tool/milestone_review.sh M1 --skip-all             # quick: just diff + prompt
bash tool/milestone_review.sh M1 --context docs/design/soliplex-agent-package.md
```

The script:
1. Runs `flutter test` + `dart test` (packages)
2. Runs `flutter analyze --fatal-infos`
3. Captures per-package metrics (source lines, test lines, test count)
4. Auto-detects diff range from `(M{N})` commit message tags
5. Extracts milestone spec from this document
6. Assembles a structured review prompt that:
   - Provides the milestone spec as ground truth
   - Includes the unified diff as the primary artifact to analyze
   - Passes changed source files + context files alongside
   - Forces chain-of-thought: Gemini must analyze each rubric item
     against the actual diff before rendering a verdict
7. Outputs the `mcp__gemini__read_files` call with the file list

**Review prompt structure** (generated into `M{N}-prompt.md`):
- Role assignment: adversarial Principal Engineer
- Instruction to read diff first, cross-reference with source files
- 8-point rubric (correctness, containment, tests, style, platform
  safety, KISS/YAGNI, immutability, package boundary)
- Milestone spec extracted from this document
- Diff stats + metrics delta + test/analyze status
- Gemini must produce per-rubric-item analysis with diff line citations

The review is executed via `mcp__gemini__read_files` with
`model="gemini-3.1-pro-preview"`. The prompt forces structured
output — no hand-wavy approvals.

## Architecture Level

Decided via triple-review (Gemini 3.1 Pro, Codex, Claude agent):

- **No Uncle Bob / Clean Architecture ceremony.** No use-case interactors,
  no repository interfaces wrapping `SoliplexApi`, no entity base classes,
  no `domain/`/`data/`/`presentation/` layer folders.
- **One interface: `HostApi`.** The platform boundary (pure Dart cannot
  call Flutter). Earned its existence.
- **One constraint object: `PlatformConstraints`.** Interface because
  platform detection varies (native vs WASM).
- **Everything else concrete.** Constructor injection of `SoliplexApi`,
  `AgUiClient`, `ToolRegistry`, `Logger`. Tests mock concrete types
  with `mocktail`.
- **Sealed class hierarchies** for state machines (`RunState`,
  `AgentResult`).
- **Package boundaries enforce layer separation.** No nested layers
  within the package.

## Design Doc Gaps to Resolve Before M4-M5

From the Claude agent's code-level analysis (read actual source files):

| Gap | Impact | Resolution needed |
|-----|--------|-------------------|
| `RunOrchestrator` internal handle pattern | Agent guesses architecture | Specify: single handle or wraps `RunRegistry` |
| `RunFinished` + pending tools = stay in `RunningState` | Breaks tool loop | Document state machine invariant |
| `messageStates` merge responsibility | Cache corruption | State who merges old+new |
| `startRun` concurrency guard | Race conditions | Specify: throw, queue, or ignore |
| `ThreadHistoryCache` takes `HostApi` but needs `SoliplexApi` | Wrong dependency | Fix doc: inject `SoliplexApi` |
| `ActiveRunState` vs `RunState` rename | Confusing | State the rename explicitly |
| `initialState` is AG-UI state needing deep merge | Lost state | Document merge behavior |

These gaps only matter for M4-M5. M1-M3 are clean.

---

## M1: Package Scaffold + Core Types

**Goal:** Compilable pure Dart package with shared vocabulary.

**~30 min. Low risk.**

### Tasks

- Create `packages/soliplex_agent/` with `pubspec.yaml`
- Create `analysis_options.yaml` including `very_good_analysis`
- Create `dcm_options.yaml` with strict thresholds (cyclomatic 10, LOC 40,
  params 4, nesting 3) and rules enabled from day one. DCM is a separate
  CLI tool — `dcm_options.yaml` is read by `dcm analyze`, not by `dart analyze`
- Smoke test: import `soliplex_client` and `soliplex_logging`, reference
  key types, pass `dart analyze`
- Define core types: `ThreadKey` typedef
  `({String serverId, String roomId, String threadId})`,
  run status types, sealed `AgentResult` (`AgentSuccess`,
  `AgentFailure`, `AgentTimedOut`)
- Setup `dart test` infrastructure

### Codex (parallel)

- Scaffold test files with boilerplate (equality tests for types,
  sealed class exhaustiveness)

### Gemini review

- Rubber-stamp, but check `pubspec.yaml` has no Flutter dependency
- Verify DCM thresholds are strict (not the relaxed app-level ones)

### Gate

- `cd packages/soliplex_agent && dart analyze && dart test`
- `dcm analyze packages/soliplex_agent` (zero warnings with strict thresholds)
- `dart format --set-exit-if-changed .` (zero diff)
- Existing app `flutter analyze` + `flutter test` unchanged
- Run `bash tool/milestone_review.sh M1` and pass Gemini review

### Capability gained

Nothing functional. But the data model is locked and reviewable by both
Flutter and Monty bridge developers. The package compiles.

---

## M2: Core Interfaces + In-Memory Mocks

**Goal:** Define the contracts. Unblock Monty bridge developer.**

**~30 min. Low risk.**

### Tasks

- Define `HostApi` interface (DataFrame registration, chart registration,
  `invoke()` dispatch)
- Define `PlatformConstraints` interface (parallel execution, async mode,
  max bridges, reentrant interpreter)
- Implement `FakeHostApi` (in-memory, for tests)
- Implement `NativePlatformConstraints` / `WebPlatformConstraints`
  (simple concrete classes with hardcoded flags)

### Codex (parallel)

- Write unit tests for the fake implementations

### Gemini review

- Verify interface matches design doc exactly

### Gate

- Interfaces tested. Green build (`dart analyze` + `dcm analyze` + `dart test`).
- `bash tool/milestone_review.sh M2` + Gemini review passes

### Capability gained

The Monty bridge developer can start coding against the `HostApi`
interface — it is now locked in as a Dart artifact, not just a
markdown spec.

---

## M3: Tool Registry + Execution

**Goal:** Standalone tool dispatcher.

**~30 min. Low risk.**

### Tasks

- Define `ToolRegistryResolver` typedef:
  `Future<ToolRegistry> Function(String roomId)`
- Build local `ToolRegistry` wrapper (if needed beyond what
  `soliplex_client` already provides)
- Wire register/lookup/execute flow
- Test: feed JSON payload, execute correct function, return result

### Codex (parallel)

- Scaffold test cases for missing tools, argument validation

### Gemini review

- Rubber-stamp. Standard registry pattern.

### Gate

- Fully unit-tested registry. Green build (`dart analyze` + `dcm analyze` + `dart test`).
- `bash tool/milestone_review.sh M3` + Gemini review passes

### Capability gained

Flutter devs can register and test local tools (GPS, clipboard, file
picker) independently of any LLM. A working tool dispatcher with no
caller yet.

---

## M4: RunOrchestrator — Happy Path

**Goal:** Basic chatbot lifecycle. Start run, get response.

**~45 min. Medium risk.**

### Pre-requisite

Resolve design gaps for Phase 2 (see table above). Write a short
behavioral contract (~50 lines) specifying stream semantics, state
machine transitions, and concurrency guard behavior.

### Tasks

- Create `RunOrchestrator` with constructor injection of `SoliplexApi`,
  `AgUiClient`, `ToolRegistry`, `PlatformConstraints`, `Logger`
- Implement state machine: Idle -> Running -> Completed/Failed
- Expose `Stream<RunState> stateChanges` + `RunState currentState`
- Implement `startRun()`, `cancelRun()`, `reset()`, `syncToThread()`

### Codex (parallel)

- Scaffold test file with mock setups for all injected dependencies

### Gemini review

- **High value.** Verify state transitions are correct. Check that
  cancel token logic is preserved. Verify stream semantics.

### Gate

- Unit tests proving lifecycle with mocks. Green build (`dart analyze` + `dcm analyze` + `dart test`).
- `bash tool/milestone_review.sh M4` + Gemini review passes

### Capability gained

Wire a Flutter UI: send a prompt, show a spinner, display the final
answer. But if the LLM asks to use a tool, it halts — no agency yet.

---

## M5: RunOrchestrator — Tool Yielding + Resume

**Goal:** Full autonomous single-agent runs with tool use.

**~60 min. High risk. This is the danger zone.**

### Tasks

- Implement suspend/resume loop for tool calls
- Depth-limited recursion for tool execution
- Cancel token support during tool execution
- `submitToolOutputs()` to resume after tool results

### Codex (parallel)

- Write multi-step simulation tests (start -> yield tool -> submit
  output -> complete)

### Gemini review

- **Highest value.** Audit the suspend/resume async logic. Verify
  `try/finally` blocks. Check that cancellation-during-tool-execution
  race is handled. Validate depth limiting.

### Gate

- Comprehensive multi-step run tests. Green build (`dart analyze` + `dcm analyze` + `dart test`).
- `bash tool/milestone_review.sh M5` + Gemini review passes

### Capability gained

**Natural resting point.** Full working AI agent. User asks
"Do I need an umbrella?", agent checks weather tool, responds "Yes."
Single-agent, single-session, fully autonomous.

### What's still missing

Manual orchestrator management for multiple agents. No WASM safety.
No multi-session coordination.

---

## M6: AgentRuntime Facade

**Goal:** Production-ready multi-agent coordinator.

**~45 min. Medium risk.**

### Tasks

- Create `AgentRuntime`: `spawn()`, `waitAll()`, `waitAny()`
- `AgentSession` state management
- WASM deadlock guard using `PlatformConstraints.supportsReentrantInterpreter`
- Ephemeral thread cleanup in `dispose()`
- Concurrency limiting via `PlatformConstraints.maxConcurrentBridges`

### Codex (parallel)

- Write tests for sealed `AgentResult` error propagation
- Write concurrent session tests

### Gemini review

- **High value.** Audit `try/finally` around WASM deadlock guard.
  Verify error propagation path from guard to `AgentFailure`.

### Gate

- End-to-end pure Dart test: init runtime, register tool, spawn agent,
  tool executes, agent completes. Green build (`dart analyze` + `dcm analyze` + `dart test`).
- `bash tool/milestone_review.sh M6` + Gemini review passes

### Capability gained

Spawn 10 agents in parallel with one call. Race them (`waitAny`) or
gather them (`waitAll`). WASM-safe. Ephemeral thread cleanup.

---

## M7: Backend Integration Scenarios

**Goal:** Validate the agent package against real backend rooms.

**Medium risk. Requires backend participation.**

M1-M6 are pure Dart with mocks. M7 proves the system works end-to-end
against real AG-UI streams, real tool definitions, and real LLM responses.
This is where we discover integration bugs that mocks hide.

### Prerequisite

- A running Soliplex backend instance (local or staging)
- Rooms pre-configured with specific capabilities

### Room Scenarios

Define a suite of rooms that exercise distinct agentic features:

| Room | Purpose | Validates |
|------|---------|-----------|
| `echo-room` | Simplest possible: send prompt, get text response | Basic `RunOrchestrator` lifecycle (M4) |
| `tool-call-room` | Agent calls a single tool (e.g. weather lookup) | Tool yielding + resume (M5) |
| `multi-tool-room` | Agent chains 2-3 tool calls in sequence | Depth-limited recursion, state transitions |
| `error-room` | Backend returns error mid-stream | Error propagation, `AgentFailure` sealed class |
| `cancel-room` | Long-running agent that we cancel mid-flight | Cancel token during tool execution |
| `dataframe-room` | Agent produces a DataFrame via Monty | `HostApi` dispatch, DataFrame rendering |
| `parallel-agents-room` | Spawn multiple agents against same room | `AgentRuntime.waitAll()` / `waitAny()` (M6) |

### Tasks

- Create `packages/soliplex_agent/integration_test/` directory
- Write one integration test per room scenario
- Tests use real `SoliplexApi` + `AgUiClient` (not mocks)
- Backend URL provided via environment variable (`SOLIPLEX_BACKEND_URL`)
- Each test asserts on the final `AgentResult` and intermediate state transitions
- Tests are tagged `@Tags(['integration'])` so they don't run in CI by default

### Gate

- All 7 room scenarios pass against a live backend
- No changes to `soliplex_agent` public API (bugs found = fix internally)
- Green build for unit tests still passes

### Capability gained

**Confidence.** The agent package is proven against real infrastructure,
not just mocks. Integration bugs (serialization mismatches, stream timing,
tool schema differences) are caught before wiring into the production app.

### What this does NOT do

- Does not touch the existing Flutter app
- Does not require any UI — tests are headless Dart
- Does not run in CI (requires backend) — developer-triggered only

---

## M8: Standalone Test Harness + Shared Type Migration

**Goal:** Visual test UI + optional shared types with existing app.

**~45 min. Low risk.**

### Test Harness

Location: `packages/soliplex_agent/example/`

```text
example/
  lib/
    main.dart              # MaterialApp, single screen
    fake_host_api.dart     # HostApi impl rendering DataFrames as DataTable
    mock_scenarios.dart    # Canned Stream<BaseEvent> sequences
  pubspec.yaml             # depends on soliplex_agent + flutter
```

**UI components:**

- `TextField` + "Start Run" / "Cancel" buttons
- Scrolling log view: every state change and lifecycle event
- DataFrame/chart rendering area (via `FakeHostApi` with real widgets)
- Scenario picker dropdown: "happy path", "tool call loop", "error
  recovery", "timeout"

All mock data — no real backend. Completely independent binary.
Does not touch the existing app.

### Shared Type Migration (optional)

- Add `soliplex_agent` to existing app's `pubspec.yaml`
- Alias or replace app's `ThreadKey` with the one from `soliplex_agent`
- Kept separate because touching the app introduces risk

### Gate

- Example app launches, scenarios execute visually. Green build.
- If shared types: existing app tests still pass.

### Capability gained

Visual validation of the full agent lifecycle. DataFrames render.
Tool calls visible. State transitions observable. All without
risking the production app.

---

## Stop Points

| After | You have | Good stopping point? |
|-------|----------|---------------------|
| M2 | Locked interfaces | Yes — unblocks Monty bridge work |
| M5 | Working single agent | **Yes — MVP for chat UI** |
| M6 | Multi-agent runtime | Yes — production-ready orchestration |
| M7 | Backend-validated agent | **Yes — proven against real rooms** |
| M8 | Visual test harness | Yes — full validation without app risk |

## Documentation Checkpoints

Architecture documentation is produced at specific boundaries — not
every milestone, only when the system's shape changes meaningfully.
Each checkpoint produces or updates markdown in `docs/design/` with
Mermaid diagrams that reflect the **actual implemented code**, not
aspirational design.

### Checkpoint 1: After M2 (Interfaces Locked)

**Trigger:** M2 gate passes. `HostApi`, `PlatformConstraints`, fakes
all exist as compiled Dart.

**Produce:** `docs/design/api-reference.md`

- Mermaid class diagram of all public types: `ThreadKey`, `HostApi`,
  `PlatformConstraints`, `AgentResult` sealed hierarchy, fakes
- Dependency graph showing what imports what
- Table of every public symbol with one-line description
- Code snippets showing how to instantiate each type in a test

**Why here:** These interfaces are the contract other developers code
against. Document them the moment they're real, not before.

### Checkpoint 2: After M5 (MVP Agent)

**Trigger:** M5 gate passes. Single-agent tool-yielding runs work
end-to-end with mocks.

**Produce:** `docs/design/orchestration-guide.md`

- Mermaid state diagram of `RunOrchestrator` — generated from actual
  state transitions in the code, not the aspirational diagram
- Mermaid sequence diagram showing a full run: startRun → stream →
  tool yield → tool execute → resume → complete
- Error flow diagrams for each `FailureReason` (auth, network, rate
  limit, tool failure)
- Decision tree: "given this `AgentResult`, what should the UI do?"
- Code snippets: how to wire `RunOrchestrator` with mocked deps

**Why here:** M5 is the MVP. Anyone integrating the agent package
needs to understand the orchestration flow. This is the onboarding
doc for Flutter developers.

### Checkpoint 3: After M6 (Multi-Agent Runtime)

**Trigger:** M6 gate passes. `AgentRuntime` with `spawn`/`waitAll`/
`waitAny` works.

**Produce:** Update `docs/design/orchestration-guide.md` +
`docs/design/runtime-guide.md`

- Mermaid diagram of `AgentRuntime` → multiple `AgentSession` →
  `RunOrchestrator` per session
- Concurrency model diagram: how `PlatformConstraints.maxConcurrent`
  limits parallel sessions
- WASM deadlock guard flow diagram
- Mermaid sequence diagram: spawn 3 agents → waitAll → collect results
- Error propagation diagram: one session fails → how does `waitAll`
  surface it?

**Why here:** Multi-agent is a qualitative jump in complexity. The
concurrency model and error propagation need visual documentation.

### Checkpoint 4: After M7 (Backend Integration)

**Trigger:** M7 gate passes. All 7 room scenarios pass against live
backend.

**Produce:** `docs/design/integration-map.md`

- Mermaid diagram mapping each room scenario to the code paths it
  exercises (which `FailureReason`, which state transitions, which
  tool registry calls)
- Data flow diagram: real AG-UI event types observed in each scenario
- Table: room → features validated → gaps found → fixes applied
- Network topology diagram: client ↔ backend ↔ LLM showing where
  each failure mode (auth, network, rate limit) occurs

**Why here:** M7 is the first time the system touches reality.
Document what was discovered, not just what was designed.

### Rules for Documentation Checkpoints

1. **Diagrams reflect code, not aspirations.** If the state machine
   has 6 states in the code, the diagram has 6 states. No "planned"
   states.
2. **Mermaid only.** No generated images, no external tools. Diagrams
   render in GitHub, diffable in PRs.
3. **Each checkpoint is a commit.** Tagged `(D{N})` in the message
   (e.g., `docs(agent): checkpoint 2 — orchestration guide (D2)`).
4. **Reviewed via `milestone_review.sh`.** Same Gemini review gate as
   code milestones, but rubric focuses on accuracy vs. implementation
   rather than code quality.
5. **Update, don't accumulate.** If a diagram from Checkpoint 2 is
   wrong by Checkpoint 3, fix it. Don't leave stale diagrams.

## Package Decisions

| Question | Answer |
|----------|--------|
| M0 package validation? | No. Bake smoke test into first 5 min of M1 |
| `soliplex_interpreter_monty` extraction timing? | AFTER `soliplex_agent` (depends on `HostApi`) |
| `soliplex_platform` package? | Premature. Keep Flutter glue in main app |
| `soliplex_client_native` changes? | None needed |
| More design docs? | No. Resolve the 7 gaps table before M4-M5 |

## Workflow: Branches and Existing Work

### Current Branch Landscape

All branches fork from `fb81ffc` on `main`.

| Branch | Ahead of main | Key content |
|--------|--------------|-------------|
| `main` | — | Production baseline |
| `feat/tool-execution-s3` | 1 commit | Tool definition wiring. **Current branch** — design docs live here (uncommitted) |
| `feat/monty-bridge-charting` | 20 commits | `soliplex_interpreter_monty` package (56 files, 7.4k lines). DataFrame engine, bridge, schema executor, tests |
| `feat/monty-bridge-s4` | 1 commit | X-Monty-Version header |
| `integration/tool-monty-demo` | 20+ commits | Merges charting + s4 + fixes. The "everything together" branch |
| `refactor/m1-extract-services` | M1 services | `RunPreparator`, `AguiEventLogger`, `RunCompletionHandler` (worktree) |

### What Already Exists on `feat/monty-bridge-charting`

`packages/soliplex_interpreter_monty/` is a working package with:

- **Bridge layer:** `DefaultMontyBridge`, `HostFunction`,
  `HostFunctionRegistry`, `HostFunctionSchema`, `HostParam`,
  `MontyBridge` interface
- **DataFrame engine:** `DataFrame`, `DfRegistry`, `df_functions.dart`
  (721 lines of df_create/filter/sort/head/etc.)
- **Schema executor:** Pydantic-style validation via Monty
- **Tool converter:** `ToolDefinitionConverter` (AG-UI Tool -> HostFunction)
- **Widgets:** `ConsoleOutputView`, `PythonRunButton` (Flutter)
- **Comprehensive tests:** 16 test files covering bridge, schema,
  DataFrame, registry, widgets

Current `soliplex_interpreter_monty` dependencies:
- `ag_ui` (git)
- `dart_monty_platform_interface` (local path)
- `flutter` SDK
- Does NOT depend on `soliplex_agent` (doesn't exist yet)
- Does NOT depend on `soliplex_client`

### How to Incorporate Charting Branch Work

The charting branch's `soliplex_interpreter_monty` was built before the
`soliplex_agent` design. The design docs describe a future state where
`soliplex_interpreter_monty` depends on `soliplex_agent` for `HostApi` and
`PlatformConstraints`. But TODAY the bridge works without those
abstractions — it uses closure-captured Riverpod `ref` instead.

**Recommended approach:**

1. **Build `soliplex_agent` (M1-M6) on a fresh branch from `main`.**
   This is greenfield — no conflicts with charting branch work.
   The new package doesn't touch any files that charting branch touches.

2. **Before M8, review the charting branch** with Gemini to produce a
   gap analysis:
   - What does `soliplex_interpreter_monty` already have that matches the design?
   - What differs from the design (e.g., `DfRegistry` is local vs
     behind `HostApi`, handler closures capture `ref` vs injected
     `ToolRegistry`)?
   - What's the minimal diff to align existing `soliplex_interpreter_monty` with
     `soliplex_agent`'s interfaces?

3. **The M8 test harness can use existing `soliplex_interpreter_monty` code.**
   The `example/` app could import `soliplex_interpreter_monty` for the DataFrame
   engine and bridge, wired through `soliplex_agent`'s `HostApi`. This
   becomes the first real integration test of both packages together.

4. **The Monty bridge rewire (design doc Phase 5) is a SEPARATE PR**
   after both packages exist:
   - Add `soliplex_agent` dependency to `soliplex_interpreter_monty`'s pubspec
   - Refactor `DefaultMontyBridge` to accept `ToolRegistry` + `HostApi`
     instead of closure-captured `ref`
   - Change `buildDfFunctions(DfRegistry)` to `buildDfFunctions(HostApi)`
   - Update `ThreadBridgeCacheNotifier` to inject dependencies

### Branching Strategy for Implementation

```text
main
  └── feat/soliplex-agent    (M1-M7, fresh from main)
        ├── PR: M1 scaffold + types
        ├── PR: M2 interfaces + mocks
        ├── PR: M3 tool registry
        ├── PR: M4 orchestrator happy path
        ├── PR: M5 tool yielding
        ├── PR: M6 runtime facade
        └── PR: M7 backend integration scenarios
              └── feat/soliplex-agent-demo    (M8, branches from M7)
                    └── PR: M8 example app + shared types
```

Each PR merges to `feat/soliplex-agent` (or directly to `main` if
preferred). The charting branch work merges separately through its
own PR path — the two workstreams don't conflict because they touch
different directories.

### Review Task: Charting Branch Audit

Before starting M8 or the bridge rewire, run a structured review:

```text
Gemini read_files on feat/monty-bridge-charting:
  packages/soliplex_interpreter_monty/lib/soliplex_interpreter_monty.dart
  packages/soliplex_interpreter_monty/lib/src/bridge/default_monty_bridge.dart
  packages/soliplex_interpreter_monty/lib/src/data/df_registry.dart
  packages/soliplex_interpreter_monty/lib/src/functions/df_functions.dart
  packages/soliplex_interpreter_monty/pubspec.yaml

Prompt: Compare against soliplex-agent-package.md and
monty-host-capabilities-integration.md. Produce a table of:
  1. What already matches the design
  2. What needs to change (with specific file + line)
  3. What's missing
  4. Estimated effort for alignment
```

This audit produces the concrete task list for the bridge rewire PR.
