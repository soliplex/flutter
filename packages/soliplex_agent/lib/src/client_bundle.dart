import 'package:soliplex_client/soliplex_client.dart';

/// Pre-wired API + AG-UI client bundle.
///
/// Returned by [createClientBundle]. Call `close` when done.
typedef ClientBundle = ({
  SoliplexApi api,
  AgUiClient agUiClient,
  Future<void> Function() close,
});

/// Creates a [ClientBundle] from a server URL.
///
/// Wires up HTTP transport, URL builder, and AG-UI client so that
/// consumers only need a server URL — no knowledge of HTTP internals.
ClientBundle createClientBundle(String serverUrl) {
  final baseUrl = '$serverUrl/api/v1';

  final apiHttpClient = DartHttpClient();
  final sseHttpClient = DartHttpClient();

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
