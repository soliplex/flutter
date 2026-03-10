import 'package:soliplex_agent/src/runtime/server_connection.dart';

/// Mutable registry for managing [ServerConnection] instances.
///
/// Mirrors how `AgentRuntime` manages sessions internally — a live set
/// of connections that changes at runtime.
class ServerRegistry {
  final Map<String, ServerConnection> _connections = {};

  /// Registers a connection. Throws [StateError] on duplicate
  /// [ServerConnection.serverId].
  void add(ServerConnection connection) {
    if (_connections.containsKey(connection.serverId)) {
      throw StateError('Server "${connection.serverId}" is already registered');
    }
    _connections[connection.serverId] = connection;
  }

  /// Removes and returns the connection for [serverId], or `null` if
  /// absent.
  ServerConnection? remove(String serverId) => _connections.remove(serverId);

  /// Returns the connection for [serverId], or `null` if absent.
  ServerConnection? operator [](String serverId) => _connections[serverId];

  /// Returns the connection for [serverId]. Throws [StateError] if
  /// missing.
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
