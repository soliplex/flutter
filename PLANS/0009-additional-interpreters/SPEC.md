# Feature Specification: Additional Interpreter Spikes

## Overview

Validate that the `BridgeEvent` interface (defined in 0008-soliplex-scripting)
is portable to non-Monty interpreter runtimes. Two spike packages probe `d4rt`
(Dart interpreter) and `js_interpreter` (JavaScript interpreter) against the
bridge contract, documenting incompatibilities and required interface changes.

## Problem Statement

The 0008 spec assumes all interpreters can:

1. Emit `Stream<BridgeEvent>` with suspend/resume semantics
2. Register host functions via `HostFunctionSchema` with named parameters
3. Capture stdout/print output and relay it as `BridgeTextContent` events
4. Enforce execution limits (timeout, memory, stack depth)

These assumptions are untested. Both `d4rt` and `js_interpreter` have
fundamentally different execution models than Monty's suspend/resume loop.
Without validation, the `BridgeEvent` interface risks becoming
Monty-specific despite being designed as runtime-agnostic.

## Requirements

### Functional Requirements

1. Each spike package must compile (`dart pub get` + `dart analyze --fatal-infos`)
2. Each spike must have passing tests covering: host function dispatch, output
   capture, and error propagation
3. Each spike must produce a `FINDINGS.md` documenting interface gaps,
   workarounds, and recommended changes to the bridge contract

### Non-Functional Requirements

1. Spike packages are throwaway — they validate assumptions, not ship code
2. No `ag_ui` dependency — spikes work against `BridgeEvent` only
3. No Flutter dependency — pure Dart packages

## Interpreter Profiles

### d4rt v0.2.2

| Property | Value |
|----------|-------|
| Package | `d4rt: ^0.2.2` |
| Language | Dart (interpreted subset) |
| Execution model | Synchronous `execute()` → `dynamic` return value |
| Host functions | `registerTopLevelFunction(name, Function)` — positional args only |
| Output capture | No built-in mechanism; `print()` goes to host stdout |
| Suspend/resume | Not supported — host function calls are inline synchronous |
| Execution limits | No timeout, memory, or stack depth controls |
| Maturity | Stable API, active maintenance |

### js_interpreter v0.0.2

| Property | Value |
|----------|-------|
| Package | `js_interpreter: ^0.0.2` |
| Language | JavaScript (subset) |
| Execution model | Synchronous `eval(code)` → `JSValue` return value |
| Host functions | `setGlobal(name, dartFunction)` — receives `List<JSValue>` |
| Output capture | No built-in `console.log`; must register custom global |
| Suspend/resume | Not supported — eval is synchronous, no continuation model |
| Execution limits | No timeout, memory, or stack depth controls |
| Maturity | v0.0.2, early stage, may hit missing features |

## Interface Mapping

### MontyBridge Contract Points

The `MontyBridge` interface (post-0008 refactor) defines these contract points
that any interpreter bridge must satisfy:

```dart
abstract class MontyBridge {
  List<HostFunctionSchema> get schemas;
  void register(HostFunction function);
  void unregister(String name);
  Stream<BridgeEvent> execute(String code);
  void dispose();
}
```

### d4rt Mapping

| Contract Point | MontyBridge | d4rt Equivalent | Gap |
|----------------|-------------|-----------------|-----|
| `register(HostFunction)` | Named params via `HostFunctionSchema.mapAndValidate()` | `registerTopLevelFunction(name, fn)` — positional `List<dynamic>` only | Must build positional→named adapter |
| `unregister(name)` | Remove from registry | No API — functions registered permanently | Recreate interpreter instance |
| `execute(code) → Stream<BridgeEvent>` | Suspend/resume loop emits events incrementally | Synchronous `execute()` returns final value | Must emit all events post-execution (no real-time tool call events) |
| `schemas` | `List<HostFunctionSchema>` | N/A — no schema concept | Maintain schema list in bridge wrapper |
| Output capture | `__console_write__` external function + Zone | `print()` goes to host stdout; no interception API | `Zone.fork` with custom `ZoneSpecification(print: ...)` |
| Execution limits | `MontyLimits(timeoutMs, memoryBytes, stackDepth)` | None | `Future.timeout()` for time only; no memory/stack controls |
| Error propagation | `MontyException` with type/message/traceback | Dart `Exception` or `Error` from interpreter | Map to `BridgeRunError(message)` |

### js_interpreter Mapping

| Contract Point | MontyBridge | js_interpreter Equivalent | Gap |
|----------------|-------------|---------------------------|-----|
| `register(HostFunction)` | Named params via `HostFunctionSchema.mapAndValidate()` | `setGlobal(name, (List<JSValue>) => ...)` | Must coerce `JSValue` → Dart types + map positional to named |
| `unregister(name)` | Remove from registry | `setGlobal(name, null)` or recreate | May work via null assignment |
| `execute(code) → Stream<BridgeEvent>` | Suspend/resume loop emits events incrementally | Synchronous `eval(code)` → `JSValue` | Must emit all events post-execution |
| `schemas` | `List<HostFunctionSchema>` | N/A | Maintain schema list in bridge wrapper |
| Output capture | `__console_write__` external function | Register `console` global with `log` method via `setGlobal` | Requires custom `console.log` implementation |
| Execution limits | `MontyLimits` | None | `Future.timeout()` for time only |
| Error propagation | `MontyException` | `JSError` or Dart exception from eval | Map to `BridgeRunError(message)` |
| Type coercion | Native Python↔Dart via Monty | `JSValue` wrapper types (JSNumber, JSString, JSBool, JSArray, JSObject) | Need bidirectional JSValue↔Dart coercion layer |

## Known Friction Areas

### d4rt

1. **No suspend/resume**: d4rt executes synchronously. When interpreted code
   calls a host function, the Dart callback runs inline and returns
   immediately. There is no way to emit `BridgeToolCallStart` → pause →
   execute handler → `BridgeToolCallResult` in real time. All tool call events
   must be buffered and emitted after execution completes.

2. **Positional-only host functions**: `registerTopLevelFunction` passes args
   as `List<dynamic>`. The bridge must maintain a positional→named mapping
   per schema, matching args by index to `HostParam` order.

3. **No execution limits**: No `MontyLimits` equivalent. Timeout can be
   approximated with `Future.timeout()` wrapping `Isolate.run()`, but memory
   and stack depth are uncontrollable.

4. **Output capture**: `print()` in interpreted Dart code calls the host's
   `print()`. This can be intercepted via `Zone.fork` with a custom
   `ZoneSpecification(print: ...)`, but only if `execute()` runs within the
   zone.

5. **No unregister**: Functions registered on a `D4rt` instance cannot be
   removed. The bridge must either recreate the instance or maintain a
   forwarding table.

### js_interpreter

1. **JSValue type coercion**: All values cross the boundary as `JSValue`
   wrappers. The bridge needs a bidirectional coercion layer:
   - `JSNumber.value` → `num` / `int`
   - `JSString.value` → `String`
   - `JSBool.value` → `bool`
   - `JSArray` → `List<Object?>` (recursive)
   - `JSObject` → `Map<String, Object?>` (recursive)
   - Dart → JS: reverse mapping for host function return values

2. **No suspend/resume**: Same as d4rt — `eval()` is synchronous. All bridge
   events must be buffered and emitted post-execution.

3. **Async host functions**: `HostFunctionHandler` returns `Future<Object?>`.
   If `eval()` is synchronous, async host functions cannot be awaited. The
   bridge must either: (a) require synchronous handlers only, or (b) evaluate
   whether `onMessage` channel supports async patterns.

4. **console.log**: No built-in `console` object. Must register a global
   `console` object with a `log` method, or register a standalone
   `console_log` function.

5. **v0.0.2 maturity**: Early version — may hit missing JS features (closures,
   prototype chain, `this` binding, etc.) that block non-trivial test
   scenarios.

## Spike Package Structure

### packages/soliplex_interpreter_d4rt/

```text
packages/soliplex_interpreter_d4rt/
  pubspec.yaml
  analysis_options.yaml
  lib/
    soliplex_interpreter_d4rt.dart          # Barrel export
    src/
      bridge_event.dart                     # BridgeEvent sealed hierarchy (copied from 0008)
      d4rt_bridge.dart                      # Abstract bridge interface
      default_d4rt_bridge.dart              # D4rt() wrapper emitting Stream<BridgeEvent>
      d4rt_execution_service.dart           # Simple execute → Stream<ConsoleEvent>
  test/
    src/
      default_d4rt_bridge_test.dart         # Host fn dispatch, output capture, errors
      d4rt_execution_service_test.dart      # Basic execute + print capture
  FINDINGS.md                               # Incompatibility report
```

### packages/soliplex_interpreter_js/

```text
packages/soliplex_interpreter_js/
  pubspec.yaml
  analysis_options.yaml
  lib/
    soliplex_interpreter_js.dart            # Barrel export
    src/
      bridge_event.dart                     # BridgeEvent sealed hierarchy (copied from 0008)
      js_bridge.dart                        # Abstract bridge interface
      default_js_bridge.dart                # JSInterpreter() wrapper emitting Stream<BridgeEvent>
      js_execution_service.dart             # Simple execute → Stream<ConsoleEvent>
  test/
    src/
      default_js_bridge_test.dart           # Host fn dispatch, output capture, errors
      js_execution_service_test.dart        # Basic execute + print capture
  FINDINGS.md                               # Incompatibility report
```

### Shared BridgeEvent Hierarchy

Both spikes copy the `BridgeEvent` sealed hierarchy from the 0008 spec
(section 4a). This is intentional duplication — if the spikes reveal
interface changes, we update the hierarchy in-place before extracting to a
shared package.

```dart
sealed class BridgeEvent { const BridgeEvent(); }
class BridgeRunStarted extends BridgeEvent { ... }
class BridgeRunFinished extends BridgeEvent { ... }
class BridgeRunError extends BridgeEvent { ... }
class BridgeStepStarted extends BridgeEvent { ... }
class BridgeStepFinished extends BridgeEvent { ... }
class BridgeToolCallStart extends BridgeEvent { ... }
class BridgeToolCallArgs extends BridgeEvent { ... }
class BridgeToolCallEnd extends BridgeEvent { ... }
class BridgeToolCallResult extends BridgeEvent { ... }
class BridgeTextStart extends BridgeEvent { ... }
class BridgeTextContent extends BridgeEvent { ... }
class BridgeTextEnd extends BridgeEvent { ... }
```

### ConsoleEvent Hierarchy

Each spike also defines its own `ConsoleEvent` sealed class (mirroring
`soliplex_interpreter_monty`'s pattern) but adapted for interpreter-specific
result types:

```dart
sealed class ConsoleEvent { const ConsoleEvent(); }
final class ConsoleOutput extends ConsoleEvent { final String text; ... }
final class ConsoleComplete extends ConsoleEvent { final String? value; final String output; ... }
final class ConsoleError extends ConsoleEvent { final String message; ... }
```

Note: `ConsoleComplete` uses `String?` for value and `String` for output
(no `MontyResourceUsage` or `MontyException` — those are Monty-specific).

## Spike Design

### d4rt Bridge Implementation Strategy

1. **Wrap `D4rt()` instance** in `DefaultD4rtBridge`
2. **Host function registration**: For each `HostFunction`, call
   `d4rt.registerTopLevelFunction(schema.name, adapter)` where `adapter`
   maps `List<dynamic>` positional args to `Map<String, Object?>` named
   params using `schema.params` order
3. **Output capture**: Run `d4rt.execute()` inside `Zone.fork` with custom
   `print` handler that buffers output
4. **Event emission**: Since execution is synchronous, buffer all tool call
   invocations during execution, then emit the full `BridgeEvent` sequence
   after `execute()` returns
5. **Error handling**: Catch interpreter exceptions, emit `BridgeRunError`

### js_interpreter Bridge Implementation Strategy

1. **Wrap `JSInterpreter()` instance** in `DefaultJsBridge`
2. **Host function registration**: For each `HostFunction`, call
   `interpreter.setGlobal(schema.name, adapter)` where `adapter` coerces
   `List<JSValue>` to Dart types and maps positional to named params
3. **Output capture**: Register `console_log` global function that buffers
   output strings
4. **Event emission**: Same as d4rt — buffer and emit post-execution
5. **Type coercion**: Build `JSValue` → Dart and Dart → `JSValue` conversion
   utilities
6. **Error handling**: Catch eval exceptions, emit `BridgeRunError`

## FINDINGS.md Template

Each spike's `FINDINGS.md` must cover:

```markdown
# Findings: <interpreter> Bridge Spike

## Summary
One-paragraph assessment of BridgeEvent interface fit.

## Interface Gaps
| BridgeEvent Contract | Expected Behavior | Actual Behavior | Severity |
|---------------------|-------------------|-----------------|----------|
| ... | ... | ... | blocking/high/medium/low |

## Workarounds Applied
| Gap | Workaround | Complexity | Acceptable for Production? |
|-----|------------|------------|---------------------------|
| ... | ... | ... | yes/no |

## Missing Features
Features that block production use (not workaround-able).

## Recommended Bridge Contract Changes
Specific changes to BridgeEvent or the bridge interface that would
improve portability across runtimes.

## Test Results
Summary of test pass/fail with notes on flaky or skipped tests.
```

## Acceptance Criteria

- [ ] `PLANS/0009-additional-interpreters/SPEC.md` exists and follows project conventions
- [ ] `packages/soliplex_interpreter_d4rt/` spike package:
  - [ ] `dart pub get` resolves
  - [ ] `dart analyze --fatal-infos` passes
  - [ ] `dart test` passes
  - [ ] `FINDINGS.md` documents interface gaps, workarounds, and recommendations
- [ ] `packages/soliplex_interpreter_js/` spike package:
  - [ ] `dart pub get` resolves
  - [ ] `dart analyze --fatal-infos` passes
  - [ ] `dart test` passes
  - [ ] `FINDINGS.md` documents interface gaps, workarounds, and recommendations
- [ ] Both FINDINGS.md files address:
  - [ ] Suspend/resume gap and buffered-event workaround
  - [ ] Host function parameter mapping (positional → named)
  - [ ] Output capture mechanism and reliability
  - [ ] Execution limits feasibility
  - [ ] Recommended changes to `BridgeEvent` interface

## References

- `PLANS/0008-soliplex-scripting/SPEC.md` — BridgeEvent hierarchy (section 4a),
  interface contracts, future runtimes table (line 735-741)
- `packages/soliplex_interpreter_monty/lib/src/bridge/monty_bridge.dart` —
  reference bridge interface
- `packages/soliplex_interpreter_monty/lib/src/monty_execution_service.dart` —
  reference execution service with suspend/resume loop
- `packages/soliplex_interpreter_monty/lib/src/console_event.dart` —
  ConsoleEvent sealed class pattern
- `packages/soliplex_interpreter_monty/lib/src/bridge/host_function.dart` —
  HostFunction + HostFunctionHandler types
- `packages/soliplex_interpreter_monty/lib/src/bridge/host_function_schema.dart` —
  HostFunctionSchema with `mapAndValidate()`
