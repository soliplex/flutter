import 'package:soliplex_agent/soliplex_agent.dart' show ClientBundle;
import 'package:soliplex_cli/src/debug_observer.dart';
import 'package:soliplex_client/soliplex_client.dart';

// Re-export the canonical bundle for non-verbose callers.
export 'package:soliplex_agent/soliplex_agent.dart'
    show ClientBundle, createClientBundle;

/// Creates a [ClientBundle] with verbose HTTP logging.
///
/// Both API and SSE clients are wrapped with [ObservableHttpClient] so
/// every request/response/stream event is printed to stderr.
ClientBundle createVerboseBundle(String serverUrl) {
  final baseUrl = '$serverUrl/api/v1';
  final observer = DebugHttpObserver();

  final apiHttpClient = ObservableHttpClient(
    client: DartHttpClient(),
    observers: [observer],
  );
  final sseHttpClient = ObservableHttpClient(
    client: DartHttpClient(),
    observers: [observer],
  );

  final transport = HttpTransport(client: apiHttpClient);
  final urlBuilder = UrlBuilder(baseUrl);

  final api = SoliplexApi(transport: transport, urlBuilder: urlBuilder);
  final agUiClient = AgUiClient(
    config: AgUiClientConfig(baseUrl: baseUrl),
    httpClient: HttpClientAdapter(client: sseHttpClient),
  );

  return (
    api: api,
    agUiClient: agUiClient,
    close: () async {
      await agUiClient.close();
      api.close();
      apiHttpClient.close();
      sseHttpClient.close();
    },
  );
}
