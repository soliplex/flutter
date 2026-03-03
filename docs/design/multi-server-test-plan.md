# Multi-Server Support — Test Plan & Definition of Done

> What "complete" means for each milestone.
> All tests use `package:test` + `package:mocktail`, matching existing
> `soliplex_agent` conventions.

---

## Shared Test Infrastructure

These mocks already exist in `test/runtime/agent_runtime_test.dart` and
can be reused:

```dart
class MockSoliplexApi extends Mock implements SoliplexApi {}
class MockAgUiClient extends Mock implements AgUiClient {}
class MockLogger extends Mock implements Logger {}
```

New shared helpers needed:

```dart
/// Creates a ServerConnection with mock clients.
ServerConnection fakeConnection(String serverId) => ServerConnection(
      serverId: serverId,
      api: MockSoliplexApi(),
      agUiClient: MockAgUiClient(),
    );

/// A no-op tool registry resolver.
final ToolRegistryResolver stubResolver =
    (_) async => const ToolRegistry();
```

---

## Phase 1: Multi-Backend

### M1: ServerConnection — `test/runtime/server_connection_test.dart`

| # | Test | Assert | Why it matters |
|---|------|--------|----------------|
| 1 | `construction exposes all fields` | `conn.serverId`, `conn.api`, `conn.agUiClient` are accessible | Basic contract |
| 2 | `equality by serverId only` | Two connections with same `serverId` but different `api` instances → `==` | Map lookup correctness |
| 3 | `inequality on different serverId` | Different `serverId` → `!=` | Prevents silent overwrites |
| 4 | `hashCode consistent with equality` | Same `serverId` → same `hashCode` | `Map<ServerConnection, _>` works |
| 5 | `toString contains serverId` | `conn.toString().contains(serverId)` | Debuggability |

**Done when:**

- 5/5 tests green
- `dart analyze --fatal-infos` clean
- Export visible from `import 'package:soliplex_agent/soliplex_agent.dart'`

---

### M2: ServerRegistry — `test/runtime/server_registry_test.dart`

| # | Test | Assert | Why it matters |
|---|------|--------|----------------|
| 1 | `add then lookup` | `registry['srv-1']` returns the connection | Core CRUD |
| 2 | `add duplicate throws StateError` | Second `add()` with same serverId throws | Prevents silent overwrites |
| 3 | `remove returns connection` | `registry.remove('srv-1')` returns it, subsequent lookup is `null` | Cleanup works |
| 4 | `remove absent returns null` | `registry.remove('nope')` → `null` | No-throw on missing |
| 5 | `operator [] absent returns null` | `registry['nope']` → `null` | Safe nullable lookup |
| 6 | `require present returns connection` | `registry.require('srv-1')` → connection | Convenience accessor |
| 7 | `require absent throws StateError` | `registry.require('nope')` throws | Fail-fast on misconfiguration |
| 8 | `serverIds reflects mutations` | After add/remove, `serverIds` is correct | Iteration correctness |
| 9 | `connections reflects mutations` | After add/remove, `connections` is correct | Iteration correctness |
| 10 | `isEmpty and length` | Empty → `isEmpty == true, length == 0`; after add → `false, 1` | Boundary conditions |

**Done when:**

- 10/10 tests green
- `dart analyze --fatal-infos` clean
- Export visible from barrel

---

### M3: AgentRuntime.fromConnection — new group in `test/runtime/agent_runtime_test.dart`

| # | Test | Assert | Why it matters |
|---|------|--------|----------------|
| 1 | `produces runtime with correct serverId` | `runtime.serverId == connection.serverId` | Identity propagation |
| 2 | `spawn creates session with matching ThreadKey.serverId` | `session.threadKey.serverId == connection.serverId` | End-to-end serverId flow |
| 3 | `existing tests still pass` | No regressions | Non-breaking change |

**Done when:**

- 2 new tests green + all existing `agent_runtime_test.dart` tests green
- `dart analyze --fatal-infos` clean

---

### Phase 1 integration check

After M1–M3, verify the full Phase 1 workflow:

```dart
test('Phase 1: registry → connection → runtime → session', () async {
  final registry = ServerRegistry()
    ..add(fakeConnection('prod'))
    ..add(fakeConnection('staging'));

  final runtime = AgentRuntime.fromConnection(
    connection: registry.require('prod'),
    toolRegistryResolver: stubResolver,
    platform: NativePlatformConstraints(),
    logger: MockLogger(),
  );

  // Mock thread creation on the 'prod' api...
  final session = await runtime.spawn(roomId: 'r1', prompt: 'hi');
  expect(session.threadKey.serverId, 'prod');
});
```

---

## Phase 2: Server-Scoped Sessions

### M4: MultiServerRuntime — `test/runtime/multi_server_runtime_test.dart`

#### Construction & lazy creation

| # | Test | Assert |
|---|------|--------|
| 1 | `runtimeFor creates lazily` | First call creates; second returns same instance |
| 2 | `runtimeFor unknown server throws StateError` | Server not in registry → `StateError` |
| 3 | `runtimeFor after dispose throws StateError` | Disposed runtime rejects all calls |

#### Routing

| # | Test | Assert |
|---|------|--------|
| 4 | `spawn routes to correct server` | `session.threadKey.serverId == requested serverId` |
| 5 | `spawn on two servers` | Sessions have different `serverId` in ThreadKey |
| 6 | `getSession routes by serverId` | Finds session on correct server runtime |
| 7 | `getSession returns null for wrong server` | `null` for non-matching serverId |

#### Aggregation

| # | Test | Assert |
|---|------|--------|
| 8 | `activeSessions lifecycle` | Empty before spawn → aggregates after multi-server spawn → empty after dispose |

#### Cross-server wait

| # | Test | Assert |
|---|------|--------|
| 9 | `waitAll collects results from multiple servers` | All results returned |
| 10 | `waitAny returns first result regardless of server` | One result returned |
| 11 | `waitAll with empty list` | Returns empty list (no hang, no error) |
| 12 | `waitAny with empty list` | Throws `ArgumentError` (Dart `Future.any` semantics) or documents behavior |

#### Routing — edge cases

| # | Test | Assert |
|---|------|--------|
| 13 | `getSession with valid serverId but unknown threadId` | Returns `null` (no throw) |

#### Lifecycle

| # | Test | Assert |
|---|------|--------|
| 14 | `cancelAll cancels all servers` | All sessions reach terminal state |
| 15 | `dispose cleans up all runtimes` | Subsequent `runtimeFor()` throws |
| 16 | `dispose is idempotent` | Second `dispose()` is a no-op, no error |
| 17 | `concurrent dispose is safe` | `Future.wait([msr.dispose(), msr.dispose()])` completes without error |

**Done when:**

- 17/17 tests green
- `dart analyze --fatal-infos` clean
- Export visible from barrel
- Single-server `AgentRuntime` tests still pass (no regressions)

---

### Phase 2 integration check

```dart
test('Phase 2: multi-server spawn + waitAll', () async {
  final registry = ServerRegistry()
    ..add(fakeConnection('prod'))
    ..add(fakeConnection('staging'));

  final msr = MultiServerRuntime(
    registry: registry,
    toolRegistryResolver: stubResolver,
    platform: NativePlatformConstraints(),
    logger: MockLogger(),
  );

  // Mock thread creation on both servers...
  final s1 = await msr.spawn(serverId: 'prod', roomId: 'r1', prompt: 'hi');
  final s2 = await msr.spawn(serverId: 'staging', roomId: 'r1', prompt: 'hi');

  expect(s1.threadKey.serverId, 'prod');
  expect(s2.threadKey.serverId, 'staging');
  expect(msr.activeSessions, hasLength(2));

  final results = await msr.waitAll([s1, s2]);
  expect(results, hasLength(2));
});
```

---

## Phase 3: Federation

### M5: FederatedToolRegistry — `test/tools/federated_tool_registry_test.dart`

#### Merge behavior

| # | Test | Assert |
|---|------|--------|
| 1 | `merge two servers prefixes all tools` | `prod::weather`, `staging::weather` |
| 2 | `merge single server still prefixes` | `prod::weather` (always prefix — no dynamic optimization) |
| 3 | `merge empty map returns empty registry` | `toToolRegistry()` has zero tools |
| 4 | `toToolRegistry length matches total` | Sum of tools across all input registries |

#### Routing correctness

| # | Test | Assert |
|---|------|--------|
| 5 | `tool execution routes to originating server` | `prod::weather` calls prod's executor, not staging's |
| 6 | `same-named tools on different servers` | `prod::weather` and `staging::weather` execute independently with correct results |

#### Reverse lookup

| # | Test | Assert |
|---|------|--------|
| 7 | `serverIdFor known tool` | `serverIdFor('prod::weather')` → `'prod'` |
| 8 | `serverIdFor unknown tool` | `serverIdFor('nope')` → `null` |

**Done when:**

- 8/8 tests green
- `dart analyze --fatal-infos` clean
- Both `ServerScopedToolRegistryResolver` and `FederatedToolRegistry` exported from barrel

---

### M6: Resolver + Integration

#### `test/tools/federated_tool_registry_resolver_test.dart`

| # | Test | Assert |
|---|------|--------|
| 1 | `resolves from all servers` | Merged registry contains tools from both servers |
| 2 | `skips failing server gracefully` | Missing room on one server → only other server's tools in result |
| 3 | `logs warning on skip` | `Logger.warning` called with server info |
| 4 | `parallel resolution` | Both servers queried concurrently (verify with timing or mock ordering) |
| 5 | `per-server timeout` | Slow server skipped after timeout, fast server's tools present |
| 6 | `survives severe async crash` | Server throws `SocketException` → caught, warning logged, surviving servers merged |

#### `test/runtime/multi_server_runtime_test.dart` — new `federation` group

| # | Test | Assert |
|---|------|--------|
| 7 | `with serverScopedResolver, spawned runtime gets federated tools` | Tools from multiple servers available in session |
| 8 | `without serverScopedResolver, Phase 2 behavior unchanged` | Only room-local tools available |
| 9 | `federated tool execution routes correctly end-to-end` | Call `prod::weather` via session → dispatches to prod server's executor |

**Done when:**

- 9/9 tests green (6 resolver + 3 integration)
- `dart analyze --fatal-infos` clean
- All Phase 1 and Phase 2 tests still pass
- Exports visible from barrel

---

### Phase 3 integration check

```dart
test('Phase 3: federated tool resolution across servers', () async {
  // Setup: prod has 'weather', staging has 'calculator'
  var prodCalled = false;
  var stagingCalled = false;

  final prodRegistry = ToolRegistry()
    ..register(ClientTool(
      name: 'weather',
      description: 'Get weather',
      executor: (_) async { prodCalled = true; return 'sunny'; },
    ));
  final stagingRegistry = ToolRegistry()
    ..register(ClientTool(
      name: 'calculator',
      description: 'Do math',
      executor: (_) async { stagingCalled = true; return '4'; },
    ));

  final registry = ServerRegistry()
    ..add(fakeConnection('prod'))
    ..add(fakeConnection('staging'));

  final serverScopedResolver = (String serverId, String roomId) async {
    if (serverId == 'prod') return prodRegistry;
    if (serverId == 'staging') return stagingRegistry;
    throw StateError('unknown server: $serverId');
  };

  // Merge via FederatedToolRegistry
  final federated = FederatedToolRegistry.merge({
    'prod': prodRegistry,
    'staging': stagingRegistry,
  });
  final merged = federated.toToolRegistry();

  // Verify prefixed names exist
  expect(merged.lookup('prod::weather'), isNotNull);
  expect(merged.lookup('staging::calculator'), isNotNull);

  // Verify reverse lookup
  expect(federated.serverIdFor('prod::weather'), 'prod');
  expect(federated.serverIdFor('staging::calculator'), 'staging');

  // Verify routing: execute prod::weather → calls prod's executor
  await merged.execute('prod::weather', {});
  expect(prodCalled, isTrue);
  expect(stagingCalled, isFalse);

  // Verify routing: execute staging::calculator → calls staging's executor
  await merged.execute('staging::calculator', {});
  expect(stagingCalled, isTrue);
});
```

---

## Full Suite Definition of Done

All milestones complete when:

- [ ] `dart test` — **all tests pass** (unit + integration)
- [ ] `dart test --coverage` — **no untested public API surface**
- [ ] `dart analyze --fatal-infos` — **zero issues**
- [ ] `dart format . --set-exit-if-changed` — **no changes**
- [ ] **No regressions** — all pre-existing tests unchanged and passing
- [ ] **Barrel exports** — all new types importable from
      `package:soliplex_agent/soliplex_agent.dart`
- [ ] **Pure Dart** — no Flutter imports in any new file

### Test count summary

| Milestone | New tests | Cumulative |
|-----------|-----------|------------|
| M1 | 5 | 5 |
| M2 | 10 | 15 |
| M3 | 2 | 17 |
| M4 | 17 | 34 |
| M5 | 8 | 42 |
| M6 | 9 | 51 |

**51 new tests** covering the full multi-server surface.

### Changes from v1 (Gemini 3.1 Pro review)

1. **+1 M2** — `operator []` absent returns null (was untested)
2. **Merged M4 #8+#9** — `activeSessions lifecycle` (one test, empty→populated→empty)
3. **+2 M4** — `waitAll`/`waitAny` with empty lists (edge case)
4. **+1 M4** — `getSession` valid server, unknown thread → null
5. **+1 M4** — concurrent `dispose()` safety
6. **-1 M5** — removed typedef-compiles test (redundant)
7. **+1 M6** — severe async crash (`SocketException`) in resolver
8. **Fixed Phase 3 integration check** — real `expect()` assertions
