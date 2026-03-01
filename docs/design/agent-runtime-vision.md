# Agent Runtime Vision

## The Big Idea: LLM-Authored Orchestration

The LLM in a room generates Python scripts at runtime. Monty executes
them. Those scripts spawn sub-agents across rooms, fan out across
knowledge bases, loop with validation, and merge results — all without
the user writing a line of code.

This is the core insight: **the agent IS the programmer**. It doesn't
just use tools — it writes orchestration programs that the client
runtime executes. The backend is a pool of stateless agent workers
(one per room/thread). The client runtime is the execution engine for
LLM-authored coordination logic. The remote backend is the source of
sub-agent state.

```text
User asks a question
    │
    ▼
LLM in Room A reasons about the task
    │  decides it needs data from 3 knowledge bases
    │  generates a Python script as its "plan"
    ▼
Monty executes the LLM-generated script
    │  spawn_agent("legal-kb"), spawn_agent("medical-kb"), ...
    │  wait_all(), validate, retry, merge
    ▼
Agent Runtime (pure Dart, in soliplex_agent)
    │  manages sessions, routes messages, propagates errors
    ▼
RunOrchestrator instances (one per sub-agent session)
    │  each session = (room, thread) + AG-UI stream
    ▼
Backend agents (stateless workers, one per room)
    │  each has its own system prompt, RAG, tool definitions
    ▼
Results flow back → Python merges → LLM synthesizes final answer
```

This is analogous to Claw-like agentic systems: the LLM self-directs
by authoring its own coordination logic. The difference is that
sub-agent state lives on the remote backend (threads are the state
containers), and the client runtime is the executor — not a cloud
orchestrator.

Threads become first-class communication primitives — not just UI
navigation targets but channels through which agents pass typed state,
coordinate work, and recover from errors.

The runtime sits on top of `soliplex_agent` (orchestration) and
`soliplex_client` (protocol), and is scripted through `soliplex_interpreter_monty`
(Python bridge).

### Why Python (Monty), Not Dart Scripting

The scripting runtime is Python for a non-negotiable practical reason:
**LLMs generate far superior Python than Dart code.** This is
especially true for the locally hosted small models running on our
backend servers. We cannot assume access to frontier models (Claude,
Gemini) — our architecture must optimize for the models we actually
deploy, which are smaller and produce reliable Python but struggle
with Dart syntax, Flutter idioms, and async patterns.

Python is the lingua franca of LLM code generation. Every model,
from 7B parameter locals to frontier, can produce working Python
orchestration scripts. Dart code generation is unreliable at smaller
scales — wrong async/await patterns, missing type annotations,
confused by Flutter-specific APIs.

This means:

- **Monty (Python bridge) is permanent infrastructure**, not a
  temporary solution
- The WASM constraints (single-threaded, non-reentrant) are real
  costs we accept because the alternative (Dart scripting) doesn't
  work with our model tier
- Alternative Dart scripting runtimes (e.g., `d4rt`) may complement
  Monty for specific use cases but cannot replace it for LLM-authored
  orchestration
- Bridge complexity (FFI, WASM bindings, mutex guards) is the price
  of using the language that models actually write well

### Monty Language Limitations

The Monty Python runtime is a **restricted subset of Python**. It does
not support `import` statements or `class` definitions. LLM-generated
scripts are flat procedural code that can only call the host functions
we explicitly register on the bridge.

This is a severe but intentional constraint:
- **No imports** — no standard library, no third-party packages. All
  capabilities come from registered host functions (`spawn_agent`,
  `wait_all`, `df_create`, etc.)
- **No classes** — no custom types, no OOP patterns. Scripts use dicts,
  lists, strings, and the return values from host functions
- **Control flow only** — `if/else`, `for`, `while`, `try/except`,
  function definitions, and variable assignment work normally
- **Host functions are the entire API surface** — every capability the
  script has comes from what we register on `DefaultMontyBridge`

This shapes the orchestration patterns significantly:

```python
# This is the FULL language available to LLM-generated scripts.
# No imports. No classes. Just host functions + control flow.

results = []
for room in ["legal-kb", "medical-kb", "finance-kb"]:
    agent = spawn_agent(room=room, prompt=question)
    results.append(agent)

answers = wait_all(results)

# Merge with string manipulation (no json module, no dataclasses)
combined = ""
for answer in answers:
    combined = combined + "\n---\n" + answer

synthesizer = spawn_agent(room="general", prompt="Synthesize:\n" + combined)
return get_result(synthesizer)
```

**Design implication:** Every orchestration primitive (`spawn_agent`,
`wait_all`, `df_create`, `df_filter`, etc.) must be a registered host
function. The LLM cannot `import` helpers or define reusable classes —
we must provide everything it needs as flat callable functions.

## What This Enables (Use Cases)

### 1. Research Pipeline — Parallel Fan-Out / Fan-In

A Python script spawns multiple agents in parallel, each searching a
different domain, then merges the results.

```python
# Python (executed by Monty in the client)
legal = spawn_agent(room="legal-kb", prompt="Find precedents for...")
medical = spawn_agent(room="medical-kb", prompt="What are the risks of...")
financial = spawn_agent(room="finance-kb", prompt="What is the cost of...")

# All three run concurrently (native) or serialized (WASM)
results = wait_all([legal, medical, financial])

# Merge results and spawn a synthesis agent
synthesis = spawn_agent(
    room="general",
    prompt=f"Synthesize these findings:\n{format_results(results)}",
)
final_answer = get_result(synthesis)
```

**Why this matters:** Today, a single agent in a single room can only
access that room's knowledge base. This pattern lets a script compose
knowledge across multiple specialized rooms without the backend needing
cross-room awareness.

### 2. Iterative Refinement Loop

Python runs an agent, inspects the output, and decides whether to retry,
refine, or accept.

```python
for attempt in range(3):
    agent = spawn_agent(
        room="analysis",
        prompt=f"Analyze this data: {data}. {refinement_hint}",
    )
    result = get_result(agent)

    # Validate output structure
    if validate_schema(result, expected_schema):
        break

    # Extract what was missing and refine
    refinement_hint = f"Previous attempt was missing: {find_gaps(result)}"
```

**Why this matters:** The LLM doesn't have a self-correction loop. Python
provides the evaluation + retry logic that makes agent outputs reliable.

### 3. Multi-Room Expert Consultation

An agent encounters a domain-specific question and delegates to a
specialist.

```python
def on_tool_call(name, args):
    if name == "consult_expert":
        domain = args["domain"]
        question = args["question"]

        expert = spawn_agent(
            room=f"{domain}-experts",
            prompt=question,
        )
        return get_result(expert)

agent = spawn_agent(
    room="general",
    prompt="Help me plan my estate...",
    tools=[consult_expert_tool],
)
```

**Why this matters:** Rooms have different system prompts, knowledge bases,
and tool configurations. An expert consultation pattern lets a generalist
agent leverage specialist rooms without the backend routing logic.

### 4. Data Processing Pipeline

Agent extracts → Python transforms → Agent summarizes. Each step's output
is the next step's input, with validation at boundaries.

```python
# Step 1: Agent extracts structured data
extractor = spawn_agent(
    room="data-extraction",
    prompt="Extract all financial figures from this document...",
)
raw_data = get_result(extractor)

# Step 2: Python transforms with DataFrame
df = df_create(parse_json(raw_data))
df = df_filter(df, "amount", ">", 10000)
df = df_sort(df, "date")
summary_csv = df_to_csv(df)

# Step 3: Agent summarizes
summarizer = spawn_agent(
    room="reporting",
    prompt=f"Create an executive summary from this data:\n{summary_csv}",
)
report = get_result(summarizer)
```

**Why this matters:** This is an ETL pipeline where the LLM handles
unstructured→structured and structured→narrative, while Python handles
the deterministic transformation in between. Neither can do the other's
job.

### 5. Error Recovery with Fallback Strategy

```python
try:
    primary = spawn_agent(room="primary-kb", prompt=question)
    result = get_result(primary, timeout=30)
except AgentTimeout:
    # Primary took too long — try a simpler approach
    fallback = spawn_agent(
        room="primary-kb",
        prompt=f"Give a brief answer: {question}",
    )
    result = get_result(fallback)
except AgentError as e:
    # Agent failed — log and return graceful degradation
    log_error(f"Agent failed: {e}")
    result = "I was unable to complete this analysis. Please try again."
```

**Why this matters:** Today, if a run fails, the UI shows an error and the
user retries manually. This pattern lets Python implement retry strategies,
timeouts, and fallbacks — making the system self-healing.

### 6. Stateful Multi-Turn Orchestration

Python maintains state across multiple agent turns, building context
incrementally.

```python
context = {}

# Turn 1: Gather requirements
agent1 = spawn_agent(room="intake", prompt="What do you need help with?")
context["requirements"] = get_result(agent1)

# Turn 2: Research based on requirements
agent2 = spawn_agent(
    room="research",
    prompt=f"Research solutions for: {context['requirements']}",
)
context["research"] = get_result(agent2)

# Turn 3: Synthesize into recommendation
agent3 = spawn_agent(
    room="advisory",
    prompt=f"""Based on:
Requirements: {context['requirements']}
Research: {context['research']}
Provide a recommendation.""",
)
context["recommendation"] = get_result(agent3)
```

**Why this matters:** Each agent session is stateless from the backend's
perspective. Python is the stateful coordinator that carries context
forward, enabling multi-step workflows that no single agent could handle.

## What This Cannot Solve

### 1. Server-Side Orchestration

This is a **client-side** runtime. The backend sees independent runs — it
has no concept of "this run is a sub-agent of that run." If the backend
needs to orchestrate (e.g., for production batch processing), that's a
different system.

**Implication:** All coordination overhead (spawning, waiting, merging) is
client-side compute and network calls. Not suitable for orchestrating
hundreds of agents — this is for interactive, user-facing workflows with
a handful of concurrent sessions.

### 2. Long-Running Background Jobs

The runtime is tied to the client session. On web (WASM), it's
single-threaded and sync-only. On native, Isolates live as long as the
app process.

**Cannot survive:**
- Browser tab close or navigation away
- App backgrounding on mobile (eventual OS kill)
- App restart

**Implication:** Workflows must complete within a user session. For
long-running jobs, the runtime could checkpoint state and resume, but
that's a separate persistence layer not covered here.

### 3. Cross-User Coordination

No concept of agents in different users' sessions communicating. This is
single-user, single-client. If User A's agent needs to coordinate with
User B's agent, that's a server-side concern.

### 4. Real-Time Inter-Agent Streaming

Agent A's AG-UI event stream is consumed by the runtime, not forwarded
live to Agent B. If Agent B needs Agent A's output, it waits for
completion, then gets the final result.

**Implication:** No "streaming pipeline" where tokens from Agent A flow
into Agent B in real-time. The communication model is request/response
at the agent boundary, not streaming.

**Future possibility:** A `tee()` primitive that forks an event stream,
letting Python process events as they arrive while also forwarding to
another agent. But this adds complexity and is deferred.

### 5. Replacing Server-Side Agent Frameworks

This is not LangChain/CrewAI/AutoGen for the client. The backend agent
(with its system prompt, RAG, tool definitions) does the actual reasoning.
The client runtime *composes* backend agents — it doesn't replace them.

If the backend agent is bad at a task, adding client-side orchestration
doesn't fix that. Garbage in → orchestrated garbage out.

### 6. Deterministic Reproducibility

Agent outputs are non-deterministic (LLM sampling). A Python script that
ran perfectly yesterday may produce different results today because the
agents returned different text. The runtime provides execution guarantees
(timeout, retry, error handling) but not output guarantees.

### 7. Eliminating the Python Bridge (Today)

The Monty bridge exists because locally hosted small models generate
reliable Python but poor Dart. The bridge complexity (FFI, WASM
bindings, mutex guards, re-entrancy deadlock guards) is the cost of
this reality.

If future models — or future locally-deployable models — produce
reliable Dart code, the bridge layer could be simplified or replaced
with a Dart-native scripting runtime (e.g., `d4rt`). The orchestration
architecture (`AgentRuntime`, `RunOrchestrator`, `HostApi`,
`ToolRegistryResolver`) would remain unchanged — only the scripting
runtime feeding `spawn_agent()` / `wait_all()` calls changes. The
host function surface, session model, and dependency injection are all
language-agnostic by design.

Until then, Monty is permanent infrastructure, and the WASM constraints
documented in this design are real costs we accept.

## The "Dartdantic" Question: Typed Contracts at Agent Boundaries

### The Problem

When Agent A's output becomes Agent B's input, what validates the shape?
Today it's free-form text. Python can `parse_json()` and hope, but there's
no schema enforcement at the boundary.

```python
# Fragile — what if agent1 returns prose instead of JSON?
result = get_result(agent1)
data = parse_json(result)  # if agent didn't return JSON
```

### What Exists Today

| Layer | Validation | Scope |
|-------|-----------|-------|
| `HostFunctionSchema` + `HostParam` | Type-checked params for Python→Dart calls | Monty bridge |
| AG-UI `Tool` schemas | JSON Schema for LLM tool parameters | Tool definitions |
| `SchemaExecutor` | Python Pydantic validation via Monty | Schema validation |
| `soliplex_client` domain types | Dart classes with fromJson | API responses |

### Where Typed Contracts Would Fit

A validation layer at agent boundaries — call it "agent contracts" — would:

1. **Define expected output schemas** for agent sessions

   ```python
   schema = AgentContract({
       "findings": list[str],
       "confidence": float,
       "sources": list[{"title": str, "url": str}],
   })

   agent = spawn_agent(room="research", prompt=..., output_contract=schema)
   result = get_result(agent)  # Validated against schema, or raises
   ```

2. **Validate at the boundary** before passing to the next agent

   ```python
   # Runtime validates agent output matches contract
   # If validation fails → AgentContractViolation error
   # Python catch block can retry with a "please return JSON" hint
   ```

3. **Provide serialization** for checkpointing and state transfer

   ```python
   # State can be serialized to JSON for persistence
   checkpoint = serialize_state(context)
   # ... later ...
   context = deserialize_state(checkpoint)
   ```

### Recommendation: Not a Separate Package (Yet)

The validation patterns already exist in `soliplex_interpreter_monty`
(`HostFunctionSchema`, `SchemaExecutor`). For agent output validation,
the simplest approach is:

1. Agent prompts include "respond in JSON matching this schema: ..."
2. Python parses the result and validates with existing `SchemaExecutor`
3. If validation fails, retry with a corrective prompt

This doesn't need a new package. It needs:
- A convention for structured agent output (prompt engineering)
- `SchemaExecutor` exposed as a host function so Python can call
  `validate_schema(result, schema)` directly
- Error types that distinguish "agent failed" from "agent returned
  invalid output"

If these patterns become complex enough to warrant their own package
(versioned schemas, schema evolution, cross-agent type safety), that's
a future extraction — same pattern as `soliplex_agent` being extracted
from the app.

## Architectural Sketch

> **Dependency injection, interfaces, and implementation phases** are
> specified in
> [`soliplex-agent-package.md`](soliplex-agent-package.md) —
> the canonical component spec. This document focuses on runtime
> behavior, use cases, and the Python API surface.

### Session Model

Each agent session is a `(room, thread)` tuple with its own
`RunOrchestrator` and AG-UI event stream. The runtime manages a
collection of sessions.

```text
AgentRuntime
  ├── Session A  (room="legal", thread=auto-created)
  │     └── RunOrchestrator → HostApi → backend
  ├── Session B  (room="medical", thread=auto-created)
  │     └── RunOrchestrator → HostApi → backend
  └── Session C  (room="finance", thread=auto-created)
        └── RunOrchestrator → HostApi → backend
```

### Python API Surface

```python
# Spawn a new agent session
agent = spawn_agent(
    room="room-id",           # Which room (knowledge base + config)
    prompt="...",             # Initial user message
    thread=None,              # Auto-create, or reuse existing
    timeout=60,               # Seconds before AgentTimeout
    output_contract=None,     # Optional schema validation
)

# Wait for result (blocking from Python's perspective)
result = get_result(agent)                # Returns final text output
result = get_result(agent, timeout=30)    # With timeout

# Wait for multiple agents
results = wait_all([a, b, c])           # All must complete
result = wait_any([a, b, c])            # First to complete wins
results = wait_all([a, b], timeout=60)  # With global timeout

# Error handling
try:
    result = get_result(agent)
except AgentTimeout:
    ...
except AgentError as e:
    ...  # e.message, e.run_id, e.partial_output
except AgentContractViolation as e:
    ...  # e.expected_schema, e.actual_output

# Cancel a running agent
cancel_agent(agent)

# Check status without blocking
if is_done(agent):
    result = get_result(agent)
```

### Dart Runtime Interface

> See [`soliplex-agent-package.md`](soliplex-agent-package.md) § "AgentRuntime"
> for the canonical Dart interfaces: `AgentRuntime`, `AgentSession`,
> `AgentResult`, and `ToolRegistryResolver`.

### How It Connects to Existing Architecture

```text
LLM in a room generates Python script at runtime
  │
  ▼
Monty executes script → calls spawn_agent(room, prompt)
  │
  ▼
Monty host function: "spawn_agent"
  │  registered as a host function on the bridge
  ▼
AgentRuntime.spawn(roomId, prompt)
  │  1. creates thread via api.createThread(roomId)
  │  2. resolves ToolRegistry via toolRegistryResolver(roomId)
  │  3. creates RunOrchestrator with resolved registry
  │  4. starts run via orchestrator.startRun()
  ▼
RunOrchestrator (one per session)
  │  uses SoliplexApi (direct injection) for backend calls
  │  uses AgUiClient (direct injection) for AG-UI streaming
  │  uses ToolRegistry (resolved per-room) for tool execution
  │  uses HostApi (optional) for GUI/native operations
  ▼
Backend (independent per-session, no cross-session awareness)
  │  each room has its own system prompt, RAG, tool definitions
  │  threads are the state containers — sub-agent state lives here
```

### WASM Constraint Impact

On web (WASM, sync-only Monty):

- `spawn_agent()` is synchronous from Python's perspective — Monty
  suspends, Dart creates the session, returns a handle
- `get_result(agent)` is also synchronous from Python's perspective —
  Monty suspends, Dart waits for the AG-UI stream to complete, returns
- **Multiple agents "in parallel" are actually interleaved** — each
  AG-UI stream runs on Dart's event loop, but Python is suspended
  waiting for `get_result()` on one at a time
- `wait_all()` is the critical primitive — Dart runs all streams
  concurrently on its event loop while Python is suspended on a single
  `resume()` call

On native (Isolate):

- Same API surface, but `RunOrchestrator` instances can genuinely run
  in parallel Isolates
- `wait_all()` benefits from true parallelism

**PlatformConstraints.maxConcurrentBridges** limits how many Monty
bridges (not agent sessions) can run simultaneously. Agent sessions use
AG-UI streams (HTTP), not Monty — so the limit is on Python execution,
not agent count. Multiple agent sessions can run concurrently even on
WASM.

### WASM Re-Entrancy Deadlock Guard

**The scenario:** Python calls `wait_all([agent_a, agent_b])` and
suspends. Dart's event loop runs both AG-UI streams concurrently.
Agent B's tool call requires Python execution (e.g., `SchemaExecutor`
validation, or a Python-based tool). But the WASM interpreter is
already suspended — it's sitting inside the `wait_all()` resume chain.
WASM is single-threaded and non-reentrant. **Hard freeze.**

**The guard:** `PlatformConstraints.supportsReentrantInterpreter`
(see [`soliplex-agent-package.md`](soliplex-agent-package.md) § "PlatformConstraints").
Before dispatching any tool that would invoke Python, the runtime
checks this flag. If `false` and Python is already suspended:

```dart
if (!platform.supportsReentrantInterpreter && _pythonSuspended) {
  throw StateError(
    'Cannot re-enter Python interpreter on WASM. '
    'Tool "${toolCall.name}" requires Python execution, but Python '
    'is suspended waiting for wait_all() to complete.',
  );
}
```

**Error propagation path (must be bulletproof):**

1. Dart throws `StateError` inside Agent B's tool execution
2. The Monty bridge's `_handlePending` catches it in a `try/finally`
3. Bridge calls `platform.resume(errorPayload)` so Python gets a
   Python `Exception` rather than freezing the Dart event loop
4. Agent B's AG-UI stream emits `ToolCallResultEvent` with the error
5. Agent B completes as `AgentFailure` with the re-entrancy error
6. `wait_all()` collects Agent B's failure alongside Agent A's result
7. Python's `try/except` on the original script handles it

**Every code path from the guard to the Python resume must be
wrapped in try/finally.** If any link in the chain doesn't handle
the error cleanly, the Dart event loop stalls because Python is
suspended and can never be resumed.

On **native**, this constraint doesn't apply — each bridge runs in
its own Isolate, so re-entrancy is not an issue.

### Error Propagation Model

Errors are **data, not exceptions** at the Dart layer. The sealed
`AgentResult` type forces the caller to handle all cases:

```dart
final result = await session.result();
switch (result) {
  case AgentSuccess(:final output):
    // Use output
  case AgentFailure(:final error, :final partialOutput):
    // Decide: retry, fallback, or propagate
  case AgentTimedOut(:final elapsed):
    // Decide: retry with longer timeout, or fail
}
```

At the Python layer, errors become exceptions (because that's idiomatic
Python):

```python
try:
    result = get_result(agent)
except AgentError as e:
    # Maps from AgentFailure
except AgentTimeout:
    # Maps from AgentTimedOut
```

The Monty bridge translates between the two models — Dart sealed types
↔ Python exceptions.

**No automatic propagation.** If a sub-agent fails, the parent Python
script's `try/except` handles it. There's no supervisor tree or automatic
retry. The script IS the supervisor. This is simpler and more explicit
than framework-level supervision.

## Where This Lives in the Package Graph

```text
soliplex_interpreter_monty
  │  host functions: spawn_agent, wait_all, etc.
  │  depends on
  ▼
soliplex_agent
  │  AgentRuntime, AgentSession, AgentResult
  │  RunOrchestrator (one per session)
  │  HostApi (injected by Flutter)
  │  depends on
  ▼
soliplex_client
  │  SoliplexApi, AG-UI types, domain models
  ▼
Backend (independent per-session)
```

The `AgentRuntime` class lives in `soliplex_agent` because it's pure Dart
orchestration. The Python host functions (`spawn_agent`, `wait_all`, etc.)
live in `soliplex_interpreter_monty` because they're Monty-specific.

## UX Boundary: What AgentRuntime Owns vs What Flutter Owns

The Flutter app does complex UX: streaming chat, tool execution cards,
charts, DataFrames, thread navigation, unread markers. Background agents
spawned by the runtime will also produce all this output. The question is
where the boundary sits between "orchestration" and "presentation."

### The Principle

**AgentRuntime produces data. Flutter decides how to present it.**

AgentRuntime emits typed events and state via streams. It never calls
"show this widget" or "navigate to this thread." The Flutter layer
subscribes to those streams and maps them to UX however it wants.

### What AgentRuntime Owns (In Scope)

| Concern | How |
|---------|-----|
| Session lifecycle (spawn, run, complete, fail, timeout, cancel) | `AgentSession` state machine |
| Concurrent stream management (N AG-UI streams on event loop) | Internal `Future` coordination |
| Tool execution orchestration (per-session depth-limited loop) | Delegates to `RunOrchestrator` per session |
| Result collection (final text, partial output on failure) | `AgentResult` sealed type |
| Coordination primitives (`waitAll`, `waitAny`, timeout) | Pure `Future.wait` / `Future.any` |
| Resource limiting (max concurrent sessions) | Internal semaphore using `PlatformConstraints` |
| Session metadata (which room, which thread, when started) | `AgentSession` properties |
| Event forwarding (AG-UI events from each session's stream) | `Stream<BaseEvent>` per session, if caller wants to observe |

### What AgentRuntime Does NOT Own (Out of Scope)

| Concern | Why | Where It Lives |
|---------|-----|----------------|
| Whether a session appears in the thread list | UX decision | Flutter: Riverpod provider filters visible vs hidden threads |
| How streaming text renders (typing indicator, markdown) | Widget concern | Flutter: `ChatPanel` / `MessageBubble` widgets |
| Tool execution card rendering | Widget concern | Flutter: `ToolCallCard` widget |
| DataFrame / chart rendering | Widget concern | Flutter: via `HostApi` implementation |
| Unread markers / badges | UX state | Flutter: `UnreadRunsProvider` listens to `sessionChanges` |
| Thread navigation (user clicks a background session) | UX interaction | Flutter: `GoRouter` + Riverpod `currentThreadIdProvider` |
| Progress indicators for background work | UX decision | Flutter: watches `AgentRuntime.activeSessions` stream |
| Sound / haptic notifications on completion | Platform concern | Flutter: conditional on platform + user preferences |
| "Show me what the agent is doing" (live observation) | UX interaction | Flutter: subscribes to session's event stream on demand |

### The Hard Cases

#### A) Background agent produces a DataFrame — does it render?

**AgentRuntime:** Doesn't know or care. The tool call happens through
the room-scoped `ToolRegistry` (resolved via `ToolRegistryResolver`).
If a `df_create` tool is registered, it runs. The result flows back into
the AG-UI stream as a `ToolCallResultEvent`.

**Flutter:** The `HostApi` implementation stores the
DataFrame in a `DfRegistry`. Whether a widget renders it depends on
whether the user is *looking at* that session's thread. If the session
is background, the DataFrame exists in memory but no widget renders it
until the user navigates there.

**No AgentRuntime change needed.** The existing tool execution path
handles this. Rendering is lazy — triggered by the user navigating to
the thread.

#### B) User navigates to a background session while it's streaming

**AgentRuntime:** Exposes `session.eventStream` — a live
`Stream<BaseEvent>`. The runtime does **not** buffer event history
in memory (unbounded AG-UI token events would be a memory leak for
long-running sessions).

**Flutter catch-up strategy: subscribe first, fetch second.**

When the user navigates to a thread with an active background session:

1. Flutter immediately subscribes to `session.eventStream` and starts
   buffering events locally in a short-lived list
2. Flutter calls `api.getThreadHistory(roomId, threadId)` to get the
   persisted history snapshot
3. When the HTTP response arrives, Flutter renders the history and
   then replays the locally buffered events to fill the gap
4. From that point forward, the live stream drives the UI directly

This avoids the race condition where events emitted during the HTTP
fetch would be lost. By subscribing *before* fetching, no events are
dropped. Deduplication by event ID handles any overlap.

```dart
// Flutter catch-up pseudocode
final session = runtime.getSession(threadKey);
if (session != null && session.state == AgentSessionState.running) {
  // 1. Subscribe immediately — buffer locally
  final catchUpBuffer = <BaseEvent>[];
  final sub = session.eventStream.listen(catchUpBuffer.add);

  // 2. Fetch persisted history
  final history = await api.getThreadHistory(roomId, threadId);
  renderHistory(history);

  // 3. Replay buffered events (deduplicate by event ID)
  for (final event in catchUpBuffer) {
    if (!alreadyRendered(event)) renderEvent(event);
  }

  // 4. Switch to live mode
  sub.onData(renderEvent);
}
```

**AgentRuntime needs:** `getSession(ThreadKey)`, `activeSessions`,
`sessionChanges` — already defined in the Dart Runtime Interface
above. No event buffering in the runtime itself.

#### C) N concurrent sessions each executing tools — state explosion

**AgentRuntime:** Each session has its own `RunOrchestrator` with its
own `RunState`. These are independent — no shared mutable state. The
runtime tracks them in a `Map<String, AgentSession>`.

**Flutter:** The hard part is the Riverpod layer. Today,
`activeRunNotifierProvider` is a singleton managing one run. With
multiple sessions, the Flutter layer needs either:

1. **Family providers:** `activeRunProvider(threadKey)` — one provider
   per session. Riverpod autoDispose handles cleanup.
2. **Single map provider:** One provider holding
   `Map<ThreadKey, RunState>`, updated by listening to all sessions.
3. **Hybrid:** The "primary" session (user is looking at it) uses the
   existing singleton. Background sessions use the runtime directly,
   no Riverpod provider until the user navigates to them.

**Recommendation:** Option 3 (hybrid). It's the least invasive. The
existing `ActiveRunNotifier` handles the foreground session. Background
sessions are invisible to Riverpod until the user navigates to their
thread, at which point the notifier swaps to that session's orchestrator.

This is purely a Flutter-layer concern. AgentRuntime doesn't know about
"foreground" vs "background."

#### D) Error in a background session — does the user see it?

**AgentRuntime:** Session completes as `AgentFailure`. The result is
available via `session.result()`. `sessionChanges` stream emits the
updated session list.

**Flutter:** The host implementation decides. Options:
- Toast notification: "Background research failed"
- Badge on the thread in the sidebar
- Silent — Python script handles the retry, user never knows
- All of the above, configurable per session

**AgentRuntime provides the signal.** Flutter decides the UX. The
runtime does NOT pop up error dialogs.

### Summary: The Contract

```text
AgentRuntime owns (pure Dart):
  - Session lifecycle (spawn, run, complete, fail, cancel)
  - Concurrent stream management (N AG-UI streams on event loop)
  - Coordination (waitAll, waitAny, timeout)
  - Backend calls via injected SoliplexApi + AgUiClient
  - State exposure via streams (sessionChanges, per-session stateChanges)
  - Active session queries (getSession, activeSessions)

HostApi (GUI + native platform boundary):
  - DataFrame registration + retrieval (for Python df_* functions)
  - Chart registration (for Python chart_* functions)
  - invoke() dispatch for platform services + extensible host ops

Flutter provides (via injection + its own Riverpod layer):
  - Constructed SoliplexApi (with auth, base URL, HTTP adapter)
  - Constructed AgUiClient (with headers, platform adapter)
  - ToolRegistryResolver (room-scoped, executors may capture ref)
  - HostApi implementation (DfRegistry, chart state, widgets)
  - All rendering decisions
  - All navigation decisions
  - All notification decisions
  - UX side effects (unread markers, cache updates, toasts)
  - The "current" concept (which room/thread the user is looking at)
```

## Open Questions

1. **Thread lifecycle.** Should `spawn_agent()` always create a new thread,
   or can it reuse an existing one? Reusing allows multi-turn conversations
   with the same agent, but complicates lifecycle (who owns the thread?).

2. **Session visibility in UI.** Should spawned sessions appear in the
   thread list? As tabs? Minimized? Or invisible (background workers)?
   This is a Flutter-layer concern but affects the `HostApi`
   interface (does it need `createThread` and `hideThread`?).

3. **Resource limits.** How many concurrent sessions before the client
   degrades? On native, HTTP connections are the bottleneck. On web,
   browser connection limits (6 per domain). Should the runtime enforce
   a concurrency cap?

4. **State serialization.** If Python builds up a `context` dict across
   sessions, can it checkpoint and restore? This needs a persistence
   API in `HostApi` (or just `localStorage` / file I/O).

5. **Streaming partial results.** Can Python observe an agent's output
   as it streams (token by token), or only after completion? Streaming
   observation enables early termination ("I've seen enough, cancel")
   but adds API complexity.

6. **Inter-session communication.** Can Session A send a message to
   Session B's thread while B is still running? This would enable
   real-time collaboration between agents but requires the backend to
   support concurrent writes to the same thread.

7. **~~Event replay depth.~~** *Resolved:* No in-memory event buffering.
   Catch-up uses `api.getThreadHistory()` + subscribe-first-fetch-second
   pattern (see Hard Case B above).

8. **Ephemeral thread cleanup.** `AgentSession(ephemeral: true)` threads
   are auto-deleted on completion. Requires `SoliplexApi.deleteThread()`.
   If the parent run crashes, `AgentRuntime.dispose()` must clean up
   ephemeral threads in a `finally` block.

9. **LLM-generated script sandboxing.** When the LLM generates Python
   that calls `spawn_agent()`, what prevents infinite recursion (agent
   spawns agent spawns agent...)? The runtime needs a max depth or max
   concurrent sessions cap. Also: should LLM-generated scripts have
   access to the full host function surface, or a restricted subset?
