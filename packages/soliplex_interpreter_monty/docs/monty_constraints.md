# Monty Interpreter Constraints

Baseline specification of what the Monty Python runtime can and cannot do.
Room designers and tool authors should consult this before writing host
functions or LLM system prompts.

## Language Restrictions

| Constraint | Detail |
|-----------|--------|
| No `import` | All capabilities come from registered host functions |
| No `class` | Flat procedural code only — dicts, lists, strings, host function returns |
| No I/O | No file, network, or system calls |
| No `async`/`await` | Synchronous execution only (M13 future) |

## Supported Control Flow

`if/else`, `for`, `while`, `try/except`, function definitions (`def`),
variable assignment, list/dict comprehensions, f-strings.

## Resource Limits

| Resource | Default | Configurable via |
|----------|---------|------------------|
| Memory | 16 MB (tool), 32 MB (play button) | `MontyLimits.memoryBytes` |
| Timeout | 5s (tool), 10s (play button) | `MontyLimits.timeoutMs` |
| Stack depth | 100 | `MontyLimits.stackDepth` |

## Boundary Types

Only JSON-serializable types cross the Python-Dart boundary:

| Python | Dart | Notes |
|--------|------|-------|
| `str` | `String` | |
| `int` | `int` | |
| `float` | `double` | `HostParamType.number` accepts both |
| `bool` | `bool` | |
| `list` | `List<Object?>` | |
| `dict` | `Map<String, Object?>` | |
| `None` | `null` | |

## Execution Model

| Aspect | Behavior |
|--------|----------|
| State | Each `execute()` starts fresh — no persistent state between calls |
| Print capture | `print()` output buffered and flushed as `TextMessage` events at end |
| Error propagation | Python exceptions → `RunErrorEvent` |
| Handler errors | Dart handler exceptions → `resumeWithError()` → Python sees error |
| Unknown functions | Calls to unregistered functions → `resumeWithError()` |
| Concurrency | Single execution at a time per bridge instance |

## Future Work

- **M13:** Async/await support (`MontyResolveFutures` handling)
- **S10:** `MontySession` for persistent state across executions
