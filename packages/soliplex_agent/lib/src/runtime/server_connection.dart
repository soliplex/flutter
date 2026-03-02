import 'package:meta/meta.dart';
import 'package:soliplex_client/soliplex_client.dart';

/// Immutable value object grouping the identifiers and clients for one
/// backend server.
///
/// Equality is by [serverId] only — two connections with the same
/// [serverId] are considered the same server regardless of client
/// instances.
@immutable
class ServerConnection {
  /// Creates a connection bundle for a single server.
  const ServerConnection({
    required this.serverId,
    required this.api,
    required this.agUiClient,
  });

  /// Unique identifier for this server (e.g. `'prod'`,
  /// `'staging.soliplex.io'`).
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
