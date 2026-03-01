# Documentation Audit Findings — 2026-02-28

Post-sprint audit of all documentation after 49 commits / ~29k lines landed in 14 hours.
Four parallel audit agents compared every doc against the actual code on `main` (`d313670`).

## How to use this file

Each task below is self-contained. Pick one, open a fresh session, and say:

> Fix task N from PLANS/0010-documentation-audit/FINDINGS.md

The tasks are ordered by priority. Tasks 1-3 are the most impactful for
Monday's team walkthrough.

---

## Task 1: Fix top-level CLAUDE.md and docs/index.md

**Why first:** These are the entry points every developer (and Claude session) reads.

### CLAUDE.md (`/CLAUDE.md`)

**1a. Project Structure (lines 19-31)** — missing 4 packages.

Current:

```text
packages/
  soliplex_client/
  soliplex_client_native/
  soliplex_logging/
```

Should be:

```text
packages/
  soliplex_agent/          # Pure Dart: agent orchestration (RunOrchestrator, AgentRuntime, AgentSession)
  soliplex_cli/            # Interactive REPL for exercising soliplex_agent
  soliplex_client/         # Pure Dart: REST API, AG-UI, domain models
  soliplex_client_native/  # Platform HTTP adapters (Cupertino)
  soliplex_interpreter_monty/ # Pure Dart: Monty Python sandbox bridge
  soliplex_logging/        # Pure Dart: logging, DiskQueue, BackendLogSink
  soliplex_scripting/      # Pure Dart: wiring ag-ui <-> interpreter bridge
```

**1b. Architecture description (line 35)** — stale.

Current:
> Three layers: UI (features/) -> Core (providers, auth, logging) -> soliplex_client (pure Dart).

Should be:
> Four layers: UI (features/) -> Core (providers, auth, logging) -> soliplex_agent (orchestration) -> soliplex_client (pure Dart). soliplex_scripting wires soliplex_agent to soliplex_interpreter_monty. soliplex_cli provides a terminal REPL over soliplex_agent.

**1c. features/ list (line 23)** — missing `debug`.

**1d. Pure Dart rule (line 46)** — should also list `soliplex_agent`, `soliplex_scripting`, `soliplex_interpreter_monty`.

**1e. Documentation section (lines 67-72)** — add link to `docs/design/index.md`.

### docs/index.md

**1f. Packages table (lines 64-69)** — add `soliplex_agent`, `soliplex_cli`, `soliplex_scripting`, `soliplex_interpreter_monty`.

**1g. Architecture mermaid diagram (lines 48-60)** — add `soliplex_agent` layer between UI and `soliplex_client`. Add `soliplex_scripting` and `soliplex_interpreter_monty`.

**1h. Package Documentation section (line 38)** — only links to `summary/client.md`. Add entries for new packages (even if just pointing to their README.md).

**1i.** Add references to `docs/design/`, `docs/planning/`, and `PLANS/`.

---

## Task 2: Fix soliplex_interpreter_monty CLAUDE.md

**File:** `packages/soliplex_interpreter_monty/CLAUDE.md`

**2a. Dependencies section (line 25)** — remove `ag_ui`. Add `meta: ^1.11.0`.

Current:

```markdown
## Dependencies
- `dart_monty_platform_interface` — MontyPlatform, MockMontyPlatform, all data types
- `ag_ui` — Tool definition types
```

Should be:

```markdown
## Dependencies
- `dart_monty_platform_interface` — MontyPlatform, MockMontyPlatform, all data types
- `meta` — @immutable annotations
```

**2b. Architecture section (lines 16-21)** — remove `PythonExecutorTool` (moved to `soliplex_scripting`). Add the missing 70% of components.

Should be:

```markdown
## Architecture

### Bridge (core agentic pipeline)
- `MontyBridge` — abstract bridge interface (`Stream<BridgeEvent> execute(code)`)
- `DefaultMontyBridge` — Monty start/resume loop, host function dispatch, emits `Stream<BridgeEvent>`
- `BridgeEvent` — sealed hierarchy (12 subtypes): protocol-agnostic lifecycle events

### Host Functions
- `HostFunction` — schema + async handler pair
- `HostFunctionSchema` — name, description, params with `mapAndValidate()`
- `HostFunctionRegistry` — groups HostFunctions by category, bulk-registers onto bridge
- `HostParam` / `HostParamType` — parameter definitions with validation

### Execution
- `MontyExecutionService` — simple start/resume loop producing `Stream<ConsoleEvent>` (play button)
- `ConsoleEvent` — sealed hierarchy: ConsoleOutput, ConsoleComplete, ConsoleError
- `ExecutionResult` — return value + resource usage + collected output

### Utilities
- `SchemaExecutor` — Python-based schema validation via Monty
- `InputVariable` / `InputVariableType` — form input variable definitions
- `MontyLimitsDefaults` — preset resource limits (tool vs play-button)
- `introspection_functions` — list_functions + help builtins
- `ToolDefinitionConverter` / `ToolNameMapping` — backend tool def → bridge schema conversion
```

**2c. Minor:** Update code comments in `host_param.dart:24`, `host_param_type.dart:21`, `tool_definition_converter.dart:12` — change "ag-ui" references to "JSON Schema export" or "tool protocol export".

---

## Task 3: Fix soliplex-agent-package.md (HIGH: stale API signatures)

**File:** `docs/design/soliplex-agent-package.md`

This is the canonical design doc for `soliplex_agent`. Multiple HIGH-severity discrepancies.

**3a. Package Structure (lines 810-854)** — 7 files listed don't exist, 2 in wrong location, 6 actual files undocumented.

Files to REMOVE from tree:

- `src/run/run_handle.dart` — never created
- `src/run/run_lifecycle_event.dart` — never created
- `src/run/run_registry.dart` — never created
- `src/cache/thread_history_cache.dart` — never created (entire `cache/` dir)
- `src/services/run_preparator.dart` — never created (entire `services/` dir)
- `src/services/agui_event_logger.dart` — never created
- `src/services/run_completion_handler.dart` — never created

Files to FIX location:
- `src/runtime/agent_result.dart` → `src/models/agent_result.dart`
- `src/runtime/tool_registry_resolver.dart` → `src/tools/tool_registry_resolver.dart`

Files to ADD:
- `src/models/failure_reason.dart`
- `src/runtime/agent_session_state.dart`
- `src/host/fake_host_api.dart`
- `src/host/native_platform_constraints.dart`
- `src/host/web_platform_constraints.dart`
- `src/run/error_classifier.dart`

**3b. RunOrchestrator constructor (lines 102-109)** — param is `platformConstraints:`, not `platform:`.

**3c. RunOrchestrator API (line 311)** — remove `RunRegistry get registry` (doesn't exist, abandoned per M4 behavioral contract).

**3d. `startRun()` signature (lines 325-331)** — remove `Map<String, dynamic>? initialState` param (doesn't exist).

**3e. AgentRuntime constructor (lines 471-478)** — remove `HostApi? hostApi` (doesn't exist). Add `String serverId = 'default'`.

**3f. AgentSession interface (lines 524-550):**
- Remove `Stream<BaseEvent> get eventStream` (doesn't exist)
- Change `Future<AgentResult> result({Duration? timeout})` → `Future<AgentResult> get result` (it's a getter)
- Add `Future<AgentResult> awaitResult({Duration? timeout})` (separate method)
- Change `Future<void> cancel()` → `void cancel()`

**3g. AgentResult (lines 556-575):**
- `AgentFailure` is missing `required FailureReason reason` field
- `FailureReason` enum is missing `cancelled` variant (has 7 values, doc shows 6)

**3h. ThreadKey sample code (line 1019)** — missing `serverId`. Change `(roomId: 'r1', threadId: 't1')` to `(serverId: 'default', roomId: 'r1', threadId: 't1')`.

**3i. pubspec (line 864)** — version is `0.1.0` (not `0.1.0-dev`), SDK is `^3.6.0` (not `>=3.0.0 <4.0.0`).

**3j. NativePlatformConstraints** — doc and runtime-guide both wrong. `maxConcurrentBridges` defaults to `4` in code, not 128 or 256. Update in:
- `docs/design/runtime-guide.md:131`
- `docs/design/monty-host-capabilities-integration.md:206`

**3k. PlatformConstraints impl location** — `monty-host-capabilities-integration.md` lines 198-218 says implementations are "in the Flutter app". They are actually in `packages/soliplex_agent/lib/src/host/`.

---

## Task 4: Fix docs/design/ stale `soliplex_monty` references

~50 references to old package name `soliplex_monty` across design docs. Actual name: `soliplex_interpreter_monty`.

Files to update:
- `docs/design/monty-host-capabilities-integration.md` (30+ references)
- `docs/design/implementation-milestones.md` (16+ references, also has file paths like `packages/soliplex_monty/` that don't exist)
- `docs/design/diagrams.md`
- `docs/design/agent-runtime-vision.md` (4+ references)
- `docs/design/index.md` (lines 10, 22)

Global find/replace: `soliplex_monty` → `soliplex_interpreter_monty`
Also fix any `packages/soliplex_monty/` file paths → `packages/soliplex_interpreter_monty/`.

---

## Task 5: Fix soliplex_scripting SPEC.md + obsolete monty-host doc

### SPEC.md (`PLANS/0008-soliplex-scripting/SPEC.md`)

**5a. BridgeRunStarted/BridgeRunFinished (lines 90-101)** — spec shows no fields. Code has `threadId` and `runId` fields on both. Update the sealed hierarchy in section 4a.

**5b. PythonExecutorTool (lines 516-537)** — spec shows top-level `const pythonExecutorToolDefinition`. Code uses `abstract final class PythonExecutorTool` with static members. Update code sample.

**5c. AgUiBridgeAdapter (lines 161-197)** — spec shows free function `adaptToAgUi()`. Code is a class `AgUiBridgeAdapter` with `adapt()` and `mapEvent()` methods. Update section 4b.

**5d. BridgeCache (lines 460-470)** — spec shows `required PlatformConstraints platform`. Code takes `required int limit`. Update constructor.

**5e. MontyToolExecutor (lines 436-448)** — spec shows `threadKey` extracted from `toolCall.threadKey`. Code takes `threadKey` at construction. Update constructor and `execute()` pseudocode.

**5f. _collectTextResult (lines 620-622)** — spec says it accumulates `BridgeTextContent` + `BridgeToolCallResult`. Code only accumulates `BridgeTextContent`. Update the comment.

**5g. Dependency graph (lines 54-66)** — missing `soliplex_client` dependency. Add it.

**5h. Open Questions (lines 760-766)** — all 5 resolved by implementation. Mark them resolved with the actual outcomes.

### monty-host-capabilities-integration.md

**5i.** This entire document describes a pre-refactor architecture where `DefaultMontyBridge` takes `ToolRegistry`, `HostApi`, and `PlatformConstraints` in its constructor. The actual architecture decouples these into `HostFunctionWiring` in `soliplex_scripting`. Options:
- Add a banner: "SUPERSEDED by PLANS/0008-soliplex-scripting/SPEC.md — retained for historical context"
- Or rewrite to reflect the actual architecture

---

## Task 6: Add README.md + example to each package

Packages needing README.md:
- `packages/soliplex_agent/` — no README.md, no CLAUDE.md
- `packages/soliplex_scripting/` — no README.md, no CLAUDE.md
- `packages/soliplex_interpreter_monty/` — no README.md (has CLAUDE.md, fixed in Task 2)
- `packages/soliplex_cli/` — has README.md, no CLAUDE.md

Packages that may already have README.md (verify):
- `packages/soliplex_client/`
- `packages/soliplex_client_native/`
- `packages/soliplex_logging/`

Each README.md should include:
- One-line description
- Quick start (`dart pub get`, `dart test`, etc.)
- Architecture overview (key classes and their roles)
- Dependencies
- Example usage snippet

Each package should also have an `example/` directory with a minimal runnable example (or at minimum an `example/example.dart` file with a doc comment showing usage).

---

## Verification

After all fixes, run:

```bash
npx markdownlint-cli "CLAUDE.md" "docs/**/*.md" "PLANS/**/*.md" "packages/*/README.md" "packages/*/CLAUDE.md"
```

Ensure no broken internal links (`[text](path)` where path doesn't exist).

---

## Reference: Audit source agents

| Agent | Scope | Key findings |
|-------|-------|-------------|
| interpreter-monty audit | CLAUDE.md, barrel export, pubspec, code comments | CLAUDE.md stale (ag_ui, PythonExecutorTool), 70% of architecture undocumented |
| soliplex_agent audit | All docs referencing agent, 10 design docs, actual code | 22 discrepancies: wrong file tree, stale API sigs, wrong defaults |
| soliplex_scripting audit | SPEC.md, MILESTONES.md, interpreter + scripting code | 17 discrepancies: spec deviates from impl, monty-host doc obsolete |
| top-level + CLI audit | CLAUDE.md, index.md, client.md, CLI, PLANS/0009 | 21 discrepancies: 4 packages missing everywhere, stale diagrams |
