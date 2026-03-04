import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show AgUiClient, SoliplexApi, SoliplexHttpClient;
import 'package:soliplex_client_native/soliplex_client_native.dart';

/// Base URL for the backend, set on connect.
final baseUrlProvider = NotifierProvider<_BaseUrl, String>(_BaseUrl.new);

class _BaseUrl extends Notifier<String> {
  @override
  String build() => 'http://localhost:8000';

  void set(String url) => state = url;
}

/// Platform HTTP client — Riverpod owns lifecycle.
final httpClientProvider = Provider<SoliplexHttpClient>((ref) {
  final client = createPlatformClient();
  ref.onDispose(client.close);
  return client;
});

/// Pre-wired server connection (API + AG-UI client).
final connectionProvider = Provider<ServerConnection>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);
  final httpClient = ref.watch(httpClientProvider);
  return ServerConnection.create(
    serverId: 'default',
    serverUrl: baseUrl,
    httpClient: httpClient,
  );
});

/// The SoliplexApi instance — main communication interface.
final apiProvider = Provider<SoliplexApi>((ref) {
  return ref.watch(connectionProvider).api;
});

/// AG-UI client for streaming events.
final agUiClientProvider = Provider<AgUiClient>((ref) {
  return ref.watch(connectionProvider).agUiClient;
});
