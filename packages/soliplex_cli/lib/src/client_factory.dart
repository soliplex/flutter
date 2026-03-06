import 'package:soliplex_agent/soliplex_agent.dart' show ServerConnection;
import 'package:soliplex_cli/src/debug_observer.dart';
import 'package:soliplex_client/soliplex_client.dart';

export 'package:soliplex_agent/soliplex_agent.dart' show ServerConnection;

/// Creates a [ServerConnection] with verbose HTTP logging.
///
/// Both API and SSE clients are wrapped with [ObservableHttpClient] so
/// every request/response/stream event is printed to stderr.
ServerConnection createVerboseConnection(String serverUrl) {
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
  final agUiStreamClient = AgUiStreamClient(
    httpClient: sseHttpClient,
    urlBuilder: urlBuilder,
  );

  return ServerConnection(
    serverId: 'default',
    api: api,
    agUiStreamClient: agUiStreamClient,
    onClose: () async {
      apiHttpClient.close();
      sseHttpClient.close();
    },
  );
}
