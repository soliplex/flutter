# Multi-Server Support — Design Spec

## Status

**Draft** — March 2026

## Problem

`soliplex_agent` already has multi-server primitives (`serverId` in
`ThreadKey`, per-instance `SoliplexApi`/`AgUiClient`), but no coordinator
layer to manage multiple servers simultaneously. Today, connecting to N
servers requires manually constructing N `AgentRuntime` instances and
coordinating sessions across them in application code.

## Goal

Add a first-class multi-server layer inside `packages/soliplex_agent/`
(pure Dart). Three capabilities, delivered in three phases:

1. **Multi-Backend** — bundle per-server clients into a value object,
   manage them via a registry.
2. **Server-Scoped Sessions** — a single `MultiServerRuntime` manages
   sessions across multiple servers.
3. **Federation** — agents on one server can call tools defined on another
   server.

Flutter app integration is out of scope.

## Scope

All changes are in `packages/soliplex_agent/`. No new dependencies. Pure
Dart only.

---

## Phase 1: Multi-Backend

### Motivation

Callers need a type-safe way to bundle the three objects required to talk
to a single server (`serverId`, `SoliplexApi`, `AgUiClient`) and a
registry to manage many such bundles.

### New Types

#### `ServerConnection` (`lib/src/runtime/server_connection.dart`)

Immutable value object grouping the identifiers and clients for one
backend server.

```dart
import 'package:meta/meta.dart';
import 'package:soliplex_client/soliplex_client.dart';

@immutable
class ServerConnection {
  const ServerConnection({
    required this.serverId,
    required this.api,
    required this.agUiClient,
  });

  /// Unique identifier for this server (e.g. 'prod', 'staging.soliplex.io').
  final String serverId;

  /// REST API client for this server.
  final SoliplexApi api;

  /// AG-UI streaming client for this server.
  final AgUiClient agUiClient;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerConnection && serverId == other.serverId;

  @override
  int get hashCode => serverId.hashCode;

  @override
  String toString() => 'ServerConnection(serverId: $serverId)';
}
```

**Design decisions:**

- Equality is by `serverId` only. Two connections with the same `serverId`
  are considered the same server regardless of client instances.
- Immutable (`@immutable`, `const` constructor) to match existing codebase
  style (see `AgentResult`, `ClientTool`).
- No dispose responsibility — the caller owns `SoliplexApi` and
  `AgUiClient` lifetimes.

#### `ServerRegistry` (`lib/src/runtime/server_registry.dart`)

Mutable registry for managing `ServerConnection` instances.

```dart
class ServerRegistry {
  final Map<String, ServerConnection> _connections = {};

  /// Registers a connection. Throws [StateError] on duplicate serverId.
  void add(ServerConnection connection) {
    if (_connections.containsKey(connection.serverId)) {
      throw StateError(
        'Server "${connection.serverId}" is already registered',
      );
    }
    _connections[connection.serverId] = connection;
  }

  /// Removes and returns the connection for [serverId], or null if absent.
  ServerConnection? remove(String serverId) => _connections.remove(serverId);

  /// Returns the connection for [serverId], or null if absent.
  ServerConnection? operator [](String serverId) =>
      _connections[serverId];

  /// Returns the connection for [serverId]. Throws [StateError] if missing.
  ServerConnection require(String serverId) {
    final connection = _connections[serverId];
    if (connection == null) {
      throw StateError('No server registered with id "$serverId"');
    }
    return connection;
  }

  /// All registered server IDs.
  Iterable<String> get serverIds => _connections.keys;

  /// All registered connections.
  Iterable<ServerConnection> get connections => _connections.values;

  /// Number of registered servers.
  int get length => _connections.length;

  /// Whether the registry is empty.
  bool get isEmpty => _connections.isEmpty;
}
```

**Design decisions:**

- Mutable (not `@immutable`) because it models a live set of connections
  that changes at runtime. Mirrors how `AgentRuntime._sessions` is managed
  internally.
- `add()` throws on duplicate to prevent silent overwrites. Callers must
  `remove()` first if re-registration is intended.
- `require()` parallels the `ToolRegistry.lookup()` throw-on-missing
  pattern.

### Modified Types

#### `AgentRuntime.fromConnection()` named constructor

Convenience factory that delegates to the existing constructor, extracting
fields from a `ServerConnection`.

```dart
// In agent_runtime.dart — new named constructor:

AgentRuntime.fromConnection({
  required ServerConnection connection,
  required ToolRegistryResolver toolRegistryResolver,
  required PlatformConstraints platform,
  required Logger logger,
}) : this(
       api: connection.api,
       agUiClient: connection.agUiClient,
       toolRegistryResolver: toolRegistryResolver,
       platform: platform,
       logger: logger,
       serverId: connection.serverId,
     );
```

This is a pure delegation — no new fields, no behavioral changes.

#### Barrel exports (`lib/soliplex_agent.dart`)

Add two lines:

```dart
export 'src/runtime/server_connection.dart';
export 'src/runtime/server_registry.dart';
```

### New Test Files

#### `test/runtime/server_connection_test.dart`

Coverage targets:

| Test | Assertion |
|------|-----------|
| construction | All fields accessible |
| equality by serverId | Same serverId → equal, different → not equal |
| hashCode by serverId | Consistent with equality |
| toString | Contains serverId |

#### `test/runtime/server_registry_test.dart`

Coverage targets:

| Test | Assertion |
|------|-----------|
| add + lookup | `registry['id']` returns added connection |
| add duplicate throws | `StateError` on second `add()` with same serverId |
| remove | Returns connection and clears it |
| remove absent | Returns null |
| require present | Returns connection |
| require absent throws | `StateError` |
| serverIds | Iterable of registered IDs |
| connections | Iterable of registered connections |
| isEmpty / length | Correct before and after mutations |

#### `test/runtime/agent_runtime_test.dart` — new group

Add a `fromConnection` group to the existing test file:

| Test | Assertion |
|------|-----------|
| produces runtime with correct serverId | `runtime.serverId == connection.serverId` |
| spawn creates session with matching ThreadKey | `session.threadKey.serverId == connection.serverId` |

### Acceptance Criteria

- [ ] All existing tests pass unchanged
- [ ] `ServerRegistry` CRUD works correctly (see test matrix above)
- [ ] `AgentRuntime.fromConnection()` produces sessions with correct
      `serverId` in `ThreadKey`
- [ ] `dart analyze --fatal-infos` clean
- [ ] `dart format . --set-exit-if-changed` clean

---

## Phase 2: Server-Scoped Sessions

### Motivation

With Phase 1, callers can bundle and register connections, but they still
manage per-server `AgentRuntime` instances manually. `MultiServerRuntime`
provides a single entry point that routes operations to the correct
server's runtime.

### New Types

#### `MultiServerRuntime` (`lib/src/runtime/multi_server_runtime.dart`)

Coordinator wrapping per-server `AgentRuntime` instances.

```dart
import 'dart:async';

import 'package:soliplex_agent/src/host/platform_constraints.dart';
import 'package:soliplex_agent/src/models/agent_result.dart';
import 'package:soliplex_agent/src/models/thread_key.dart';
import 'package:soliplex_agent/src/runtime/agent_runtime.dart';
import 'package:soliplex_agent/src/runtime/agent_session.dart';
import 'package:soliplex_agent/src/runtime/server_registry.dart';
import 'package:soliplex_agent/src/tools/tool_registry_resolver.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

class MultiServerRuntime {
  MultiServerRuntime({
    required ServerRegistry registry,
    required ToolRegistryResolver toolRegistryResolver,
    required PlatformConstraints platform,
    required Logger logger,
  })  : _registry = registry,
        _toolRegistryResolver = toolRegistryResolver,
        _platform = platform,
        _logger = logger;

  final ServerRegistry _registry;
  final ToolRegistryResolver _toolRegistryResolver;
  final PlatformConstraints _platform;
  final Logger _logger;

  final Map<String, AgentRuntime> _runtimes = {};
  bool _disposed = false;

  /// Returns (lazily creating) the [AgentRuntime] for [serverId].
  ///
  /// Throws [StateError] if [serverId] is not in the registry or
  /// this runtime is disposed.
  AgentRuntime runtimeFor(String serverId) {
    _guardNotDisposed();
    return _runtimes.putIfAbsent(serverId, () {
      final connection = _registry.require(serverId);
      return AgentRuntime.fromConnection(
        connection: connection,
        toolRegistryResolver: _toolRegistryResolver,
        platform: _platform,
        logger: _logger,
      );
    });
  }

  /// Spawns a session on the specified server.
  ///
  /// Delegates to the per-server [AgentRuntime]. All parameters are
  /// forwarded directly to [AgentRuntime.spawn].
  Future<AgentSession> spawn({
    required String serverId,
    required String roomId,
    required String prompt,
    String? threadId,
    Duration? timeout,
    bool ephemeral = true,
  }) {
    return runtimeFor(serverId).spawn(
      roomId: roomId,
      prompt: prompt,
      threadId: threadId,
      timeout: timeout,
      ephemeral: ephemeral,
    );
  }

  /// All active sessions across all servers.
  List<AgentSession> get activeSessions {
    return [
      for (final runtime in _runtimes.values)
        ...runtime.activeSessions,
    ];
  }

  /// Finds a session by [ThreadKey], routing via serverId.
  AgentSession? getSession(ThreadKey key) {
    final runtime = _runtimes[key.serverId];
    return runtime?.getSession(key);
  }

  /// Waits for all given sessions to complete.
  Future<List<AgentResult>> waitAll(
    List<AgentSession> sessions, {
    Duration? timeout,
  }) {
    return Future.wait(
      sessions.map((s) => s.awaitResult(timeout: timeout)),
    );
  }

  /// Returns the first result from any of the given sessions.
  Future<AgentResult> waitAny(
    List<AgentSession> sessions, {
    Duration? timeout,
  }) {
    return Future.any(
      sessions.map((s) => s.awaitResult(timeout: timeout)),
    );
  }

  /// Cancels all active sessions across all servers.
  Future<void> cancelAll() async {
    for (final runtime in _runtimes.values) {
      await runtime.cancelAll();
    }
  }

  /// Disposes all per-server runtimes and marks this instance as
  /// disposed.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final runtime in _runtimes.values) {
      await runtime.dispose();
    }
    _runtimes.clear();
  }

  void _guardNotDisposed() {
    if (_disposed) {
      throw StateError('MultiServerRuntime has been disposed');
    }
  }
}
```

**Design decisions:**

- **Lazy creation** — `runtimeFor()` creates `AgentRuntime` instances on
  first access, not upfront. This avoids allocating resources for servers
  that are registered but never used.
- **Delegates to `AgentRuntime`** — does not reimplement concurrency
  guards, ephemeral cleanup, or session tracking. Per-server constraints
  are enforced by the underlying `AgentRuntime`.
- **`waitAll`/`waitAny` are session-level** — they work on arbitrary
  session lists, which may span servers. They delegate to
  `AgentSession.awaitResult()` directly rather than routing through
  runtimes.
- **No stream aggregation yet** — `sessionChanges` across servers is
  deferred. Callers can subscribe to individual runtimes via
  `runtimeFor(serverId).sessionChanges`.

#### Barrel exports (`lib/soliplex_agent.dart`)

Add one line:

```dart
export 'src/runtime/multi_server_runtime.dart';
```

### New Test File

#### `test/runtime/multi_server_runtime_test.dart`

Coverage targets:

| Test | Assertion |
|------|-----------|
| runtimeFor creates lazily | First call creates, second returns same instance |
| runtimeFor unknown server throws | `StateError` for unregistered serverId |
| spawn routes to correct server | `session.threadKey.serverId` matches requested serverId |
| spawn on two servers | Sessions from different servers have different `serverId` in ThreadKey |
| activeSessions aggregates | Returns sessions from all servers |
| getSession routes by serverId | Finds session on correct server |
| getSession returns null for wrong server | `null` for non-matching serverId |
| waitAll across servers | Collects results from multiple servers |
| waitAny across servers | Returns first result regardless of server |
| cancelAll cancels all servers | All sessions reach terminal state |
| dispose cleans up all runtimes | Subsequent operations throw `StateError` |
| dispose is idempotent | Second `dispose()` is a no-op |

### Acceptance Criteria

- [ ] Spawn routes to correct server by `serverId`
- [ ] Sessions from different servers have different `serverId` in
      `ThreadKey`
- [ ] `waitAll`/`waitAny` work across servers
- [ ] Dispose cleans up all runtimes
- [ ] Single-server `AgentRuntime` still works independently (no changes
      to its behavior)
- [ ] `dart analyze --fatal-infos` clean
- [ ] `dart format . --set-exit-if-changed` clean

---

## Phase 3: Federation

### Motivation

An agent running on server A may need to invoke a tool that is only
available on server B. Federation lets `MultiServerRuntime` build a merged
tool registry that routes execution to the originating server.

### New Types

#### `ServerScopedToolRegistryResolver` (`lib/src/tools/server_scoped_tool_registry_resolver.dart`)

A variant of `ToolRegistryResolver` that also takes a `serverId`.

```dart
import 'package:soliplex_client/soliplex_client.dart';

/// Resolves a [ToolRegistry] scoped to both server and room.
///
/// Parallel to [ToolRegistryResolver] but aware of which server the
/// room belongs to. Used by federation to query tool availability
/// across servers.
typedef ServerScopedToolRegistryResolver = Future<ToolRegistry> Function(
  String serverId,
  String roomId,
);
```

#### `FederatedToolRegistry` (`lib/src/tools/federated_tool_registry.dart`)

Merges tool registries from multiple servers with `serverId::toolName`
prefixed routing.

```dart
import 'package:meta/meta.dart';
import 'package:soliplex_client/soliplex_client.dart';

@immutable
class FederatedToolRegistry {
  /// Merges registries from multiple servers.
  ///
  /// Tool names are prefixed with `serverId::` to prevent collisions.
  /// When only one server contributes, tools are **not** prefixed
  /// (single-server optimization).
  ///
  /// Example:
  /// - Input: `{'prod': registry1, 'staging': registry2}`
  /// - Output registry contains: `prod::weather`, `staging::weather`,
  ///   `prod::calculator`, etc.
  factory FederatedToolRegistry.merge(
    Map<String, ToolRegistry> registries,
  );

  /// Returns a standard [ToolRegistry] with routing executors.
  ///
  /// Each tool's executor strips the server prefix and dispatches
  /// to the originating server's executor.
  ToolRegistry toToolRegistry();

  /// Reverse lookup: returns the serverId that owns [federatedName].
  ///
  /// Returns `null` if [federatedName] is not a federated tool.
  String? serverIdFor(String federatedName);
}
```

**Design decisions:**

- **`serverId::toolName` naming** — double-colon separator is unambiguous
  (tool names don't contain `::`). Parallels Rust's module separator and
  is human-readable in logs/UI.
- **Single-server optimization** — when only one server contributes,
  tools keep their original unprefixed names. This makes federation a
  no-op for the common case and avoids confusing tool names when there's
  no ambiguity.
- **Routing executors** — the `ToolRegistry` returned by
  `toToolRegistry()` wraps each tool's executor to strip the prefix and
  dispatch to the originating server's `ToolRegistry.execute()`. The
  federated registry holds references to the source registries.
- **Immutable** — once merged, the federated registry is fixed.
  Re-merging requires creating a new instance.

#### `FederatedToolRegistryResolver` (`lib/src/tools/federated_tool_registry_resolver.dart`)

Factory that queries all servers and merges their tool registries.

```dart
import 'package:soliplex_agent/src/runtime/server_registry.dart';
import 'package:soliplex_agent/src/tools/federated_tool_registry.dart';
import 'package:soliplex_agent/src/tools/server_scoped_tool_registry_resolver.dart';
import 'package:soliplex_agent/src/tools/tool_registry_resolver.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

class FederatedToolRegistryResolver {
  const FederatedToolRegistryResolver({
    required ServerRegistry registry,
    required ServerScopedToolRegistryResolver resolver,
    required Logger logger,
  });

  /// Produces a [ToolRegistryResolver] that, for a given roomId,
  /// queries all registered servers and merges the results.
  ///
  /// Servers that fail to resolve (e.g. room doesn't exist on that
  /// server) are gracefully skipped with a warning log.
  ToolRegistryResolver toToolRegistryResolver();
}
```

**Design decisions:**

- **Graceful skip on failure** — if a server doesn't have a room, the
  resolver logs a warning and excludes that server from the merge. This
  prevents one server's missing room from blocking all tool resolution.
- **Returns `ToolRegistryResolver`** — the output is a standard typedef,
  so it plugs directly into `AgentRuntime` without API changes.

### Modified Types

#### `MultiServerRuntime` — optional federation

Add an optional `ServerScopedToolRegistryResolver? serverScopedResolver`
parameter. When provided, `runtimeFor()` uses
`FederatedToolRegistryResolver` instead of the plain
`ToolRegistryResolver`.

```dart
// New parameter in constructor:
MultiServerRuntime({
  required ServerRegistry registry,
  required ToolRegistryResolver toolRegistryResolver,
  required PlatformConstraints platform,
  required Logger logger,
  ServerScopedToolRegistryResolver? serverScopedResolver, // NEW
});
```

When `serverScopedResolver` is null, behavior is identical to Phase 2
(no federation). When provided, each per-server `AgentRuntime` receives a
federated resolver that merges tools from all servers.

#### Barrel exports (`lib/soliplex_agent.dart`)

Add three lines:

```dart
export 'src/tools/federated_tool_registry.dart';
export 'src/tools/federated_tool_registry_resolver.dart';
export 'src/tools/server_scoped_tool_registry_resolver.dart';
```

### New Test Files

#### `test/tools/federated_tool_registry_test.dart`

Coverage targets:

| Test | Assertion |
|------|-----------|
| merge two servers | Federated names are `serverId::toolName` |
| merge single server | Names are unprefixed |
| merge empty map | Returns empty registry |
| toToolRegistry length | Matches total tools across servers |
| tool execution routes correctly | Dispatches to originating server's executor |
| serverIdFor known tool | Returns correct serverId |
| serverIdFor unknown tool | Returns null |
| duplicate tool name across servers | Both prefixed, no collision |

#### `test/tools/federated_tool_registry_resolver_test.dart`

Coverage targets:

| Test | Assertion |
|------|-----------|
| resolves from all servers | Merged registry contains tools from all servers |
| skips failing server | Missing room on one server doesn't block others |
| single server returns unprefixed | Optimization applies |
| logs warning on skip | Logger receives warning for failed resolution |

### Acceptance Criteria

- [ ] `FederatedToolRegistry.merge()` correctly prefixes and routes
- [ ] Tool execution dispatches to originating server's executor
- [ ] Servers lacking a room are gracefully skipped
- [ ] Single-server returns unprefixed registry
- [ ] `MultiServerRuntime` without federation works exactly as Phase 2
- [ ] `dart analyze --fatal-infos` clean
- [ ] `dart format . --set-exit-if-changed` clean

---

## File Change Summary

| Phase | New files | Modified files |
|-------|-----------|----------------|
| 1 | `server_connection.dart`, `server_registry.dart`, 2 tests | `soliplex_agent.dart`, `agent_runtime.dart`, `agent_runtime_test.dart` |
| 2 | `multi_server_runtime.dart`, 1 test | `soliplex_agent.dart` |
| 3 | `server_scoped_tool_registry_resolver.dart`, `federated_tool_registry.dart`, `federated_tool_registry_resolver.dart`, 2 tests | `soliplex_agent.dart`, `multi_server_runtime.dart` |

**Total: 11 new files, 4 existing files modified (all additive).**

## Critical Existing Files

These files are read/consumed but not modified (except where noted):

| File | Role |
|------|------|
| `lib/src/runtime/agent_runtime.dart` | Core runtime to compose with (**modified in Phase 1**) |
| `lib/src/tools/tool_registry_resolver.dart` | Existing typedef to parallel |
| `lib/soliplex_agent.dart` | Barrel exports (**modified in all phases**) |
| `packages/soliplex_client/.../tool_registry.dart` | `ToolRegistry`/`ClientTool` APIs consumed by federation |
| `test/runtime/agent_runtime_test.dart` | Test patterns to follow (**modified in Phase 1**) |

## Verification

Run after each phase:

```bash
cd packages/soliplex_agent
dart pub get
dart format . --set-exit-if-changed
dart analyze --fatal-infos
dart test
dart test --coverage
```

## Open Questions

None at this time. All types compose with existing interfaces and the
plan is purely additive.
