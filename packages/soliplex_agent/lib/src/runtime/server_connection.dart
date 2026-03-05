import 'package:soliplex_client/soliplex_client.dart';

/// Bundle of API clients for a single backend server.
///
/// Two factory constructors cover the common wiring patterns:
///
/// * [ServerConnection.fromUrl] — self-contained; creates and owns its own
///   HTTP clients. Used by CLI and TUI consumers.
/// * [ServerConnection.create] — external; caller provides (and owns) the
///   HTTP client. Used by Riverpod / platform-specific wiring.
///
/// Call [close] when the connection is no longer needed.
class ServerConnection {
  /// Creates a connection from pre-built clients.
  const ServerConnection({
    required this.serverId,
    required this.api,
    required this.agUiClient,
    Future<void> Function()? onClose,
  }) : _onClose = onClose;

  /// Self-contained factory — creates and owns its own HTTP clients.
  ///
  /// [serverUrl] must be the root URL (e.g. `http://localhost:8000`).
  /// The `/api/v1` prefix is added automatically — do not include it.
  factory ServerConnection.fromUrl({
    required String serverUrl,
    String serverId = 'default',
  }) {
    assert(
      !serverUrl.endsWith('/api/v1') && !serverUrl.endsWith('/api/v1/'),
      'serverUrl should be the root URL without /api/v1 suffix. '
      'Got: $serverUrl',
    );
    final baseUrl = '$serverUrl/api/v1';
    final apiHttpClient = DartHttpClient();
    final sseHttpClient = DartHttpClient();
    return ServerConnection(
      serverId: serverId,
      api: SoliplexApi(
        transport: HttpTransport(client: apiHttpClient),
        urlBuilder: UrlBuilder(baseUrl),
      ),
      agUiClient: AgUiClient(
        config: AgUiClientConfig(baseUrl: baseUrl),
        httpClient: HttpClientAdapter(client: sseHttpClient),
      ),
      onClose: () async {
        apiHttpClient.close();
        sseHttpClient.close();
      },
    );
  }

  /// External-client factory — caller owns the HTTP client lifecycle.
  ///
  /// [serverUrl] must be the root URL (e.g. `http://localhost:8000`).
  /// The `/api/v1` prefix is added automatically — do not include it.
  factory ServerConnection.create({
    required String serverId,
    required String serverUrl,
    required SoliplexHttpClient httpClient,
    Future<void> Function()? onClose,
  }) {
    assert(
      !serverUrl.endsWith('/api/v1') && !serverUrl.endsWith('/api/v1/'),
      'serverUrl should be the root URL without /api/v1 suffix. '
      'Got: $serverUrl',
    );
    final baseUrl = '$serverUrl/api/v1';
    return ServerConnection(
      serverId: serverId,
      api: SoliplexApi(
        transport: HttpTransport(client: httpClient),
        urlBuilder: UrlBuilder(baseUrl),
      ),
      agUiClient: AgUiClient(
        config: AgUiClientConfig(baseUrl: baseUrl),
        httpClient: HttpClientAdapter(client: httpClient),
      ),
      onClose: onClose,
    );
  }

  /// Unique identifier for this server (e.g. `'prod'`,
  /// `'staging.soliplex.io'`).
  final String serverId;

  /// REST API client for this server.
  final SoliplexApi api;

  /// AG-UI streaming client for this server.
  final AgUiClient agUiClient;

  final Future<void> Function()? _onClose;

  /// Closes the API and AG-UI clients, then invokes any injected teardown.
  Future<void> close() async {
    await agUiClient.close();
    api.close();
    await _onClose?.call();
  }

  @override
  String toString() => 'ServerConnection(serverId: $serverId)';
}
