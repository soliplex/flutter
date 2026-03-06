import 'dart:async';
import 'dart:convert';

import 'package:ag_ui/ag_ui.dart' hide CancelToken;
// ignore: implementation_imports
import 'package:ag_ui/src/sse/sse_parser.dart';
import 'package:soliplex_client/src/errors/exceptions.dart';
import 'package:soliplex_client/src/http/http_response.dart';
import 'package:soliplex_client/src/http/soliplex_http_client.dart';
import 'package:soliplex_client/src/utils/cancel_token.dart';
import 'package:soliplex_client/src/utils/url_builder.dart';

/// Streams AG-UI events using the Soliplex HTTP stack directly.
///
/// Replaces [AgUiClient] usage in pure Dart packages. Routes SSE through
/// [SoliplexHttpClient] so auth, observability, and platform clients
/// apply automatically. No retry, no reconnection, no duplicate
/// CancelToken.
class AgUiStreamClient {
  /// Creates a client that streams AG-UI events via [httpClient].
  AgUiStreamClient({
    required SoliplexHttpClient httpClient,
    required UrlBuilder urlBuilder,
  })  : _httpClient = httpClient,
        _urlBuilder = urlBuilder;

  final SoliplexHttpClient _httpClient;
  final UrlBuilder _urlBuilder;

  /// Streams AG-UI events for a run.
  ///
  /// Posts [input] to [endpoint] and parses the SSE response into
  /// typed [BaseEvent]s. The endpoint is relative to the base URL
  /// (e.g. `'rooms/my-room/agui/thread-1/run-1'`).
  Stream<BaseEvent> runAgent(
    String endpoint,
    SimpleRunAgentInput input, {
    CancelToken? cancelToken,
  }) async* {
    final response = await _httpClient.requestStream(
      'POST',
      _urlBuilder.build(path: endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      },
      body: input.toJson(),
      cancelToken: cancelToken,
    );

    _checkStatusCode(response);

    final sseMessages = SseParser().parseBytes(response.body);
    const decoder = EventDecoder();

    await for (final message in sseMessages) {
      if (message.data == null || message.data!.isEmpty) continue;
      final jsonData = json.decode(message.data!);
      if (jsonData is Map<String, dynamic>) {
        yield decoder.decodeJson(jsonData);
      } else if (jsonData is List) {
        for (final item in jsonData) {
          if (item is Map<String, dynamic>) {
            yield decoder.decodeJson(item);
          }
        }
      }
    }
  }

  /// Checks the HTTP status code and throws on non-2xx responses.
  ///
  /// Drains the response body to release the TCP socket before throwing.
  void _checkStatusCode(StreamedHttpResponse response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    // Drain the stream to release the underlying TCP socket.
    unawaited(response.body.listen((_) {}).cancel());

    final reason = response.reasonPhrase;
    throw ApiException(
      message: 'SSE connection failed: HTTP ${response.statusCode}'
          '${reason != null ? ' ($reason)' : ''}',
      statusCode: response.statusCode,
    );
  }

  /// Closes the underlying HTTP client.
  void close() => _httpClient.close();
}
