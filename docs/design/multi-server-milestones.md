# Multi-Server Support — Implementation Milestones

> **Source:** `soliplex-flutter/docs/design/multi-server-support.md`
> (branch: `docs/multi-server-spec`)
>
> **Revised** based on Gemini 3.1 Pro review: consolidated M4+M5,
> merged M6 into M5, added missing ACs, flagged single-server
> optimization risk.

---

## Parallelization

```text
M1 ──┬── M3 (depends on M1 only)
M2 ──┘
      ├── M4 (depends on M1, M2, M3)
M5 ───┘   (federation types — no Phase 1/2 dependency)
      └── M6 (depends on M4 + M5)
```

M1 and M2 can run in parallel. M3 depends only on M1.
M5 (federation types) has **no dependency** on Phase 1/2 and can be
built in parallel with M1–M4. M6 is the final sync point.

---

## Phase 1: Multi-Backend

### M1: ServerConnection value object

**Scope:** `packages/soliplex_agent/lib/src/runtime/server_connection.dart`

- [ ] Create `ServerConnection` immutable value object
  - Fields: `serverId`, `api` (SoliplexApi), `agUiClient` (AgUiClient)
  - Equality/hashCode by `serverId` only
  - `@immutable`, `const` constructor
- [ ] Add test file `test/runtime/server_connection_test.dart`
  - Construction, equality, hashCode, toString
- [ ] Export from `lib/soliplex_agent.dart`

**Acceptance:**
- `dart analyze --fatal-infos` clean
- `dart format . --set-exit-if-changed` clean
- All tests pass

---

### M2: ServerRegistry CRUD

**Scope:** `packages/soliplex_agent/lib/src/runtime/server_registry.dart`

- [ ] Create `ServerRegistry` mutable registry class
  - `add()` — throws `StateError` on duplicate
  - `remove()` — returns connection or null
  - `operator []` — nullable lookup
  - `require()` — throws on missing
  - `serverIds`, `connections`, `length`, `isEmpty`
- [ ] Add test file `test/runtime/server_registry_test.dart`
  - Full CRUD test matrix (add, duplicate, remove, require, iterables)
- [ ] Export from `lib/soliplex_agent.dart`

**Acceptance:**
- `dart analyze --fatal-infos` clean
- `dart format . --set-exit-if-changed` clean
- All tests pass

---

### M3: AgentRuntime.fromConnection factory

**Scope:** `packages/soliplex_agent/lib/src/runtime/agent_runtime.dart`

- [ ] Add `AgentRuntime.fromConnection()` named constructor
  - Pure delegation to existing constructor, extracting from `ServerConnection`
- [ ] Add `fromConnection` test group in `test/runtime/agent_runtime_test.dart`
  - Correct serverId propagation
  - Spawned sessions have matching `ThreadKey.serverId`

**Acceptance:**
- Existing tests unchanged and passing
- `dart analyze --fatal-infos` clean
- `dart format . --set-exit-if-changed` clean

---

## Phase 2: Server-Scoped Sessions

### M4: MultiServerRuntime

**Scope:** `packages/soliplex_agent/lib/src/runtime/multi_server_runtime.dart`

- [ ] Create `MultiServerRuntime` class
  - Lazy `runtimeFor(serverId)` — creates `AgentRuntime` on first access
  - `spawn()` — routes to correct server by serverId
  - `activeSessions` — aggregates across all servers
  - `getSession(ThreadKey)` — routes by serverId
  - `waitAll(sessions)` — `Future.wait` across servers
  - `waitAny(sessions)` — `Future.any` across servers
  - `cancelAll()` — cancels all servers
  - `dispose()` — idempotent cleanup
- [ ] Add test file `test/runtime/multi_server_runtime_test.dart`
  - Lazy creation, unknown server throws, routing correctness
  - Cross-server aggregation, cancelAll
  - `waitAll`/`waitAny` cross-server semantics
  - Dispose cleanup, idempotency, and concurrent dispose safety
- [ ] Export from `lib/soliplex_agent.dart`

**Acceptance:**
- Spawn routes to correct server
- Sessions have correct `serverId` in `ThreadKey`
- `waitAll`/`waitAny` work across servers
- `dispose()` is idempotent and safe under concurrent calls
- Single-server `AgentRuntime` unaffected
- `dart analyze --fatal-infos` clean
- `dart format . --set-exit-if-changed` clean

---

## Phase 3: Federation

### M5: FederatedToolRegistry

**Scope:**
- `packages/soliplex_agent/lib/src/tools/server_scoped_tool_registry_resolver.dart`
- `packages/soliplex_agent/lib/src/tools/federated_tool_registry.dart`

> **Note — can be built in parallel with M1–M4** (no Phase 1/2 dependency).

- [ ] Create `ServerScopedToolRegistryResolver` typedef
  - `Future<ToolRegistry> Function(String serverId, String roomId)`
- [ ] Create `FederatedToolRegistry` immutable class
  - `factory FederatedToolRegistry.merge(Map<String, ToolRegistry>)`
  - **Always prefix** tool names with `serverId::` (deterministic naming —
    see Risk note below)
  - `toToolRegistry()` — returns standard `ToolRegistry` with routing executors
  - `serverIdFor(federatedName)` — reverse lookup
- [ ] Add test file `test/tools/federated_tool_registry_test.dart`
  - Merge two servers, single server, empty map
  - Routing correctness, reverse lookup
  - Same-named tools on different servers execute their respective server's code
  - `toToolRegistry()` length matches total tools across servers
- [ ] Export both from `lib/soliplex_agent.dart`

**Risk — single-server optimization removed:**
The original spec proposed omitting the `serverId::` prefix when only one
server contributes. Gemini review flagged this as high risk: if a second
server is added at runtime, tool names shift dynamically from `weather`
to `prod::weather`, silently breaking LLM prompts. We always prefix to
keep tool names deterministic. This can be revisited later behind an
explicit opt-in flag if needed.

**Acceptance:**
- Merge correctly prefixes and routes
- Tool execution dispatches to originating server's executor
- Same-named tools on different servers both work correctly
- `dart analyze --fatal-infos` clean
- `dart format . --set-exit-if-changed` clean

---

### M6: FederatedToolRegistryResolver + MultiServerRuntime integration

**Scope:**
- `packages/soliplex_agent/lib/src/tools/federated_tool_registry_resolver.dart`
- `packages/soliplex_agent/lib/src/runtime/multi_server_runtime.dart` (modified)

- [ ] Create `FederatedToolRegistryResolver` class
  - Takes `ServerRegistry`, `ServerScopedToolRegistryResolver`, `Logger`
  - `toToolRegistryResolver()` — queries all servers in parallel
    (`Future.wait` with per-server timeout), merges, graceful skip on failure
- [ ] Modify `MultiServerRuntime` — optional `serverScopedResolver` parameter
  - When provided, uses `FederatedToolRegistryResolver`
  - When null, Phase 2 behavior unchanged
- [ ] Add test file `test/tools/federated_tool_registry_resolver_test.dart`
  - All servers resolved, failing server skipped, single server prefixed, warning logged
- [ ] Add federation wiring tests in `test/runtime/multi_server_runtime_test.dart`
  - Verify spawned `AgentRuntime` receives federated tools when
    `serverScopedResolver` is provided
  - Verify Phase 2 behavior unchanged when `serverScopedResolver` is null
- [ ] Export from `lib/soliplex_agent.dart`

**Acceptance:**
- Federation merges tools from all servers
- Failing servers gracefully skipped (with logged warning)
- Parallel resolution with per-server timeouts
- `MultiServerRuntime` without federation works exactly as Phase 2
- `multi_server_runtime_test.dart` covers federation wiring
- `dart analyze --fatal-infos` clean
- `dart format . --set-exit-if-changed` clean

---

## Milestone Summary

| Milestone | Phase | Deliverable | New Files | Modified Files | Parallelizable |
|-----------|-------|-------------|-----------|----------------|----------------|
| M1 | 1 | ServerConnection | 2 | 1 (barrel) | Yes (with M2) |
| M2 | 1 | ServerRegistry | 2 | 1 (barrel) | Yes (with M1) |
| M3 | 1 | AgentRuntime.fromConnection | 0 | 2 (runtime + test) | After M1 |
| M4 | 2 | MultiServerRuntime | 2 | 1 (barrel) | After M1–M3 |
| M5 | 3 | FederatedToolRegistry | 3 | 1 (barrel) | Yes (with M1–M4) |
| M6 | 3 | Resolver + integration | 2 | 3 (barrel + runtime + test) | After M4 + M5 |

**Total: 11 new files, 4 existing files modified (all additive)**

## Key Changes from v1

1. **Merged M4+M5** — `waitAll`/`waitAny` are one-liners, not worth a separate milestone
2. **Merged M6 typedef into M5** — a single typedef doesn't warrant its own milestone
3. **Removed single-server optimization** — always prefix `serverId::` for deterministic tool names
4. **Added concurrent dispose AC** to M4
5. **Added federation wiring tests** to M6 (in `multi_server_runtime_test.dart`)
6. **Added parallel resolution** with per-server timeouts to M6
7. **Added same-name tool AC** to M5 — verify tools with identical names on different servers

## Verification (run after each milestone)

```bash
cd packages/soliplex_agent
dart pub get
dart format . --set-exit-if-changed
dart analyze --fatal-infos
dart test
dart test --coverage
```
