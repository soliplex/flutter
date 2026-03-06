import 'dart:async';
import 'dart:convert';

import 'package:ag_ui/ag_ui.dart' hide CancelToken;
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/src/errors/exceptions.dart';
import 'package:soliplex_client/src/http/agui_stream_client.dart';
import 'package:soliplex_client/src/http/http_response.dart';
import 'package:soliplex_client/src/http/soliplex_http_client.dart';
import 'package:soliplex_client/src/utils/cancel_token.dart';
import 'package:soliplex_client/src/utils/url_builder.dart';
import 'package:test/test.dart';

class MockSoliplexHttpClient extends Mock implements SoliplexHttpClient {}

/// Encodes a list of SSE events into a byte stream.
///
/// Each event is a JSON object wrapped in `data: ...\n\n`.
Stream<List<int>> sseByteStream(List<Map<String, dynamic>> events) {
  final buffer = StringBuffer();
  for (final event in events) {
    buffer
      ..writeln('data: ${json.encode(event)}')
      ..writeln();
  }
  return Stream.value(utf8.encode(buffer.toString()));
}

void main() {
  late MockSoliplexHttpClient mockClient;
  late AgUiStreamClient client;

  const baseUrl = 'https://api.test/v1';

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(CancelToken());
  });

  setUp(() {
    mockClient = MockSoliplexHttpClient();
    client = AgUiStreamClient(
      httpClient: mockClient,
      urlBuilder: UrlBuilder(baseUrl),
    );
    when(() => mockClient.close()).thenReturn(null);
  });

  tearDown(() {
    client.close();
    reset(mockClient);
  });

  group('AgUiStreamClient', () {
    const endpoint = 'rooms/test-room/agui/thread-1/run-1';
    const input = SimpleRunAgentInput();

    group('runAgent', () {
      test('passes CancelToken to requestStream', () async {
        final token = CancelToken();

        when(
          () => mockClient.requestStream(
            any(),
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => StreamedHttpResponse(
            statusCode: 200,
            body: sseByteStream([]),
          ),
        );

        await client.runAgent(endpoint, input, cancelToken: token).toList();

        final captured = verify(
          () => mockClient.requestStream(
            any(),
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
            cancelToken: captureAny(named: 'cancelToken'),
          ),
        ).captured;

        expect(captured.single, same(token));
      });

      test('builds correct URI from endpoint', () async {
        when(
          () => mockClient.requestStream(
            any(),
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => StreamedHttpResponse(
            statusCode: 200,
            body: sseByteStream([]),
          ),
        );

        await client.runAgent(endpoint, input).toList();

        final captured = verify(
          () => mockClient.requestStream(
            'POST',
            captureAny(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).captured;

        final uri = captured.single as Uri;
        expect(
          uri.toString(),
          '$baseUrl/$endpoint',
        );
      });

      test('sends correct headers', () async {
        when(
          () => mockClient.requestStream(
            any(),
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => StreamedHttpResponse(
            statusCode: 200,
            body: sseByteStream([]),
          ),
        );

        await client.runAgent(endpoint, input).toList();

        final captured = verify(
          () => mockClient.requestStream(
            any(),
            any(),
            headers: captureAny(named: 'headers'),
            body: any(named: 'body'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).captured;

        final headers = captured.single as Map<String, String>;
        expect(headers['Content-Type'], 'application/json');
        expect(headers['Accept'], 'text/event-stream');
      });

      test('parses single SSE events into BaseEvents', () async {
        final events = [
          {
            'type': 'RUN_STARTED',
            'threadId': 'thread-1',
            'runId': 'run-1',
          },
          {
            'type': 'TEXT_MESSAGE_START',
            'messageId': 'msg-1',
            'role': 'assistant',
          },
          {
            'type': 'TEXT_MESSAGE_CONTENT',
            'messageId': 'msg-1',
            'delta': 'Hello',
          },
          {
            'type': 'TEXT_MESSAGE_END',
            'messageId': 'msg-1',
          },
          {
            'type': 'RUN_FINISHED',
            'threadId': 'thread-1',
            'runId': 'run-1',
          },
        ];

        when(
          () => mockClient.requestStream(
            any(),
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => StreamedHttpResponse(
            statusCode: 200,
            body: sseByteStream(events),
          ),
        );

        final result = await client.runAgent(endpoint, input).toList();

        expect(result, hasLength(5));
        expect(result[0], isA<RunStartedEvent>());
        expect(result[1], isA<TextMessageStartEvent>());
        expect(result[2], isA<TextMessageContentEvent>());
        expect(
          (result[2] as TextMessageContentEvent).delta,
          'Hello',
        );
        expect(result[3], isA<TextMessageEndEvent>());
        expect(result[4], isA<RunFinishedEvent>());
      });

      test('parses batched SSE events (JSON array)', () async {
        final batch = [
          {
            'type': 'RUN_STARTED',
            'threadId': 'thread-1',
            'runId': 'run-1',
          },
          {
            'type': 'RUN_FINISHED',
            'threadId': 'thread-1',
            'runId': 'run-1',
          },
        ];

        // Encode the array as a single SSE data line.
        final sseBody = StringBuffer()
          ..writeln('data: ${json.encode(batch)}')
          ..writeln();

        when(
          () => mockClient.requestStream(
            any(),
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => StreamedHttpResponse(
            statusCode: 200,
            body: Stream.value(utf8.encode(sseBody.toString())),
          ),
        );

        final result = await client.runAgent(endpoint, input).toList();

        expect(result, hasLength(2));
        expect(result[0], isA<RunStartedEvent>());
        expect(result[1], isA<RunFinishedEvent>());
      });

      test('skips SSE messages with empty data', () async {
        // Build a stream with one empty-data message and one real event.
        final sseBody = StringBuffer()
          ..writeln('data: ')
          ..writeln()
          ..writeln('data: ${json.encode({
                'type': 'RUN_STARTED',
                'threadId': 't-1',
                'runId': 'r-1',
              })}')
          ..writeln();

        when(
          () => mockClient.requestStream(
            any(),
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => StreamedHttpResponse(
            statusCode: 200,
            body: Stream.value(utf8.encode(sseBody.toString())),
          ),
        );

        final result = await client.runAgent(endpoint, input).toList();

        expect(result, hasLength(1));
        expect(result[0], isA<RunStartedEvent>());
      });
    });

    group('error handling', () {
      test('throws ApiException on non-2xx status code', () async {
        when(
          () => mockClient.requestStream(
            any(),
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => StreamedHttpResponse(
            statusCode: 500,
            body: Stream.value(
              utf8.encode('Internal Server Error'),
            ),
            reasonPhrase: 'Internal Server Error',
          ),
        );

        expect(
          () => client.runAgent(endpoint, input).toList(),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 500)
                .having(
                  (e) => e.message,
                  'message',
                  contains('Internal Server Error'),
                ),
          ),
        );
      });

      test('throws ApiException on 401 status code', () async {
        when(
          () => mockClient.requestStream(
            any(),
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => StreamedHttpResponse(
            statusCode: 401,
            body: Stream.value(utf8.encode('Unauthorized')),
            reasonPhrase: 'Unauthorized',
          ),
        );

        expect(
          () => client.runAgent(endpoint, input).toList(),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
          ),
        );
      });

      test('includes reason phrase in error when present', () async {
        when(
          () => mockClient.requestStream(
            any(),
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => StreamedHttpResponse(
            statusCode: 503,
            body: Stream.value(utf8.encode('')),
            reasonPhrase: 'Service Unavailable',
          ),
        );

        expect(
          () => client.runAgent(endpoint, input).toList(),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              'SSE connection failed: HTTP 503 (Service Unavailable)',
            ),
          ),
        );
      });

      test('omits reason phrase from error when null', () async {
        when(
          () => mockClient.requestStream(
            any(),
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer(
          (_) async => StreamedHttpResponse(
            statusCode: 502,
            body: Stream.value(utf8.encode('')),
          ),
        );

        expect(
          () => client.runAgent(endpoint, input).toList(),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              'SSE connection failed: HTTP 502',
            ),
          ),
        );
      });
    });

    group('close', () {
      test('delegates to httpClient.close()', () {
        client.close();

        verify(() => mockClient.close()).called(1);
      });
    });
  });
}
