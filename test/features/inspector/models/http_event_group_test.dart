import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/features/inspector/models/http_event_group.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  group('HttpEventGroup', () {
    group('isStream', () {
      test('returns true when streamStart is present', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(),
        );
        expect(group.isStream, isTrue);
      });

      test('returns false when no streamStart', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
        );
        expect(group.isStream, isFalse);
      });
    });

    group('methodLabel', () {
      test('returns SSE for streaming requests', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(),
        );
        expect(group.methodLabel, 'SSE');
      });

      test('returns method for regular requests', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(method: 'POST'),
        );
        expect(group.methodLabel, 'POST');
      });

      test('returns method from error event when no request', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          error: TestData.createErrorEvent(method: 'DELETE'),
        );
        expect(group.methodLabel, 'DELETE');
      });
    });

    group('method', () {
      test('returns method from request event', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(method: 'POST'),
        );
        expect(group.method, 'POST');
      });

      test('returns method from error event when no request', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          error: TestData.createErrorEvent(method: 'DELETE'),
        );
        expect(group.method, 'DELETE');
      });

      test(
        'returns method from streamStart event when no request or error',
        () {
          final group = HttpEventGroup(
            requestId: 'req-1',
            streamStart: TestData.createStreamStartEvent(),
          );
          expect(group.method, 'GET');
        },
      );

      test('prefers request over error', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(method: 'PUT'),
          error: TestData.createErrorEvent(method: 'DELETE'),
        );
        expect(group.method, 'PUT');
      });

      test('throws StateError when no events have method', () {
        final group = HttpEventGroup(requestId: 'req-1');
        expect(() => group.method, throwsStateError);
      });

      test('throws StateError for response-only orphan group', () {
        final group = HttpEventGroup(
          requestId: 'orphan',
          response: TestData.createResponseEvent(requestId: 'orphan'),
        );
        expect(() => group.method, throwsStateError);
      });
    });

    group('uri', () {
      test('returns uri from request event', () {
        final uri = Uri.parse('http://example.com/api');
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(uri: uri),
        );
        expect(group.uri, uri);
      });

      test('returns uri from error event when no request', () {
        final uri = Uri.parse('http://example.com/error');
        final group = HttpEventGroup(
          requestId: 'req-1',
          error: TestData.createErrorEvent(uri: uri),
        );
        expect(group.uri, uri);
      });

      test('returns uri from streamStart event when no request or error', () {
        final uri = Uri.parse('http://example.com/stream');
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(uri: uri),
        );
        expect(group.uri, uri);
      });

      test('throws StateError when no events have uri', () {
        final group = HttpEventGroup(requestId: 'req-1');
        expect(() => group.uri, throwsStateError);
      });

      test('throws StateError for response-only orphan group', () {
        final group = HttpEventGroup(
          requestId: 'orphan',
          response: TestData.createResponseEvent(requestId: 'orphan'),
        );
        expect(() => group.uri, throwsStateError);
      });
    });

    group('pathWithQuery', () {
      test('returns path without query', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(
            uri: Uri.parse('http://localhost/api/rooms'),
          ),
        );
        expect(group.pathWithQuery, '/api/rooms');
      });

      test('returns path with query parameters', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(
            uri: Uri.parse('http://localhost/api/rooms?limit=50&offset=100'),
          ),
        );
        expect(group.pathWithQuery, '/api/rooms?limit=50&offset=100');
      });

      test('returns / for empty path', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(
            uri: Uri.parse('http://localhost'),
          ),
        );
        expect(group.pathWithQuery, '/');
      });

      test('returns / with query for empty path with query', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(
            uri: Uri.parse('http://localhost?foo=bar'),
          ),
        );
        expect(group.pathWithQuery, '/?foo=bar');
      });
    });

    group('timestamp', () {
      test('returns timestamp from request event', () {
        final time = DateTime(2024, 1, 15, 10, 30);
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(timestamp: time),
        );
        expect(group.timestamp, time);
      });

      test('returns timestamp from streamStart when no request', () {
        final time = DateTime(2024, 1, 15, 11);
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(timestamp: time),
        );
        expect(group.timestamp, time);
      });

      test('returns timestamp from error when no request or streamStart', () {
        final time = DateTime(2024, 1, 15, 12);
        final group = HttpEventGroup(
          requestId: 'req-1',
          error: TestData.createErrorEvent(timestamp: time),
        );
        expect(group.timestamp, time);
      });

      test('throws StateError when no events have timestamp', () {
        final group = HttpEventGroup(requestId: 'req-1');
        expect(() => group.timestamp, throwsStateError);
      });
    });

    group('status', () {
      test('returns pending when no response', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
        );
        expect(group.status, HttpEventStatus.pending);
      });

      test('returns success for 200', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
          response: TestData.createResponseEvent(),
        );
        expect(group.status, HttpEventStatus.success);
      });

      test('returns success for 201', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
          response: TestData.createResponseEvent(statusCode: 201),
        );
        expect(group.status, HttpEventStatus.success);
      });

      test('returns success for 204', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
          response: TestData.createResponseEvent(statusCode: 204),
        );
        expect(group.status, HttpEventStatus.success);
      });

      test('returns success for 299 (boundary)', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
          response: TestData.createResponseEvent(statusCode: 299),
        );
        expect(group.status, HttpEventStatus.success);
      });

      test('returns success for 1xx (non-standard)', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
          response: TestData.createResponseEvent(statusCode: 100),
        );
        expect(group.status, HttpEventStatus.success);
      });

      test('returns success for 3xx (non-standard)', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
          response: TestData.createResponseEvent(statusCode: 301),
        );
        expect(group.status, HttpEventStatus.success);
      });

      test('returns clientError for 400', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
          response: TestData.createResponseEvent(statusCode: 400),
        );
        expect(group.status, HttpEventStatus.clientError);
      });

      test('returns clientError for 403', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
          response: TestData.createResponseEvent(statusCode: 403),
        );
        expect(group.status, HttpEventStatus.clientError);
      });

      test('returns clientError for 404', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
          response: TestData.createResponseEvent(statusCode: 404),
        );
        expect(group.status, HttpEventStatus.clientError);
      });

      test('returns clientError for 499 (boundary)', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
          response: TestData.createResponseEvent(statusCode: 499),
        );
        expect(group.status, HttpEventStatus.clientError);
      });

      test('returns serverError for 500', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
          response: TestData.createResponseEvent(statusCode: 500),
        );
        expect(group.status, HttpEventStatus.serverError);
      });

      test('returns serverError for 502', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
          response: TestData.createResponseEvent(statusCode: 502),
        );
        expect(group.status, HttpEventStatus.serverError);
      });

      test('returns serverError for 503', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
          response: TestData.createResponseEvent(statusCode: 503),
        );
        expect(group.status, HttpEventStatus.serverError);
      });

      test('returns networkError when error present', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          error: TestData.createErrorEvent(),
        );
        expect(group.status, HttpEventStatus.networkError);
      });

      test('networkError takes precedence over missing response', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
          error: TestData.createErrorEvent(),
        );
        expect(group.status, HttpEventStatus.networkError);
      });

      test('returns streaming when stream started but not ended', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(),
        );
        expect(group.status, HttpEventStatus.streaming);
      });

      test('returns streamComplete when stream ends without error', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(),
          streamEnd: TestData.createStreamEndEvent(),
        );
        expect(group.status, HttpEventStatus.streamComplete);
      });

      test('returns streamError when stream ends with error', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(),
          streamEnd: TestData.createStreamEndEvent(
            error: const NetworkException(message: 'Lost connection'),
          ),
        );
        expect(group.status, HttpEventStatus.streamError);
      });

      test('streaming status takes precedence over response', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(),
          response: TestData.createResponseEvent(statusCode: 500),
        );
        expect(group.status, HttpEventStatus.streaming);
      });
    });

    group('semanticLabel', () {
      test('describes pending GET request', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(
            uri: Uri.parse('http://localhost/api/rooms'),
          ),
        );
        expect(group.semanticLabel, 'GET request to /api/rooms, pending');
      });

      test('describes successful response', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(
            method: 'POST',
            uri: Uri.parse('http://localhost/api/threads'),
          ),
          response: TestData.createResponseEvent(statusCode: 201),
        );
        expect(
          group.semanticLabel,
          'POST request to /api/threads, success, status 201',
        );
      });

      test('describes client error', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(
            uri: Uri.parse('http://localhost/api/missing'),
          ),
          response: TestData.createResponseEvent(statusCode: 404),
        );
        expect(group.semanticLabel, contains('client error'));
        expect(group.semanticLabel, contains('404'));
      });

      test('describes server error', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(
            uri: Uri.parse('http://localhost/api/error'),
          ),
          response: TestData.createResponseEvent(statusCode: 500),
        );
        expect(group.semanticLabel, contains('server error'));
        expect(group.semanticLabel, contains('500'));
      });

      test('describes network error', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          error: TestData.createErrorEvent(
            exception: const NetworkException(message: 'Timeout'),
          ),
        );
        expect(group.semanticLabel, contains('network error'));
        expect(group.semanticLabel, contains('NetworkException'));
      });

      test('describes SSE streaming', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(
            uri: Uri.parse('http://localhost/api/stream'),
          ),
        );
        expect(group.semanticLabel, 'SSE stream to /api/stream, streaming');
      });

      test('describes completed stream', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(
            uri: Uri.parse('http://localhost/api/stream'),
          ),
          streamEnd: TestData.createStreamEndEvent(),
        );
        expect(
          group.semanticLabel,
          'SSE stream to /api/stream, stream complete',
        );
      });

      test('describes stream error', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(
            uri: Uri.parse('http://localhost/api/stream'),
          ),
          streamEnd: TestData.createStreamEndEvent(
            error: const NetworkException(message: 'Lost'),
          ),
        );
        expect(group.semanticLabel, 'SSE stream to /api/stream, stream error');
      });
    });

    group('hasSpinner', () {
      test('returns true for pending status', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
        );
        expect(group.hasSpinner, isTrue);
      });

      test('returns true for streaming status', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(),
        );
        expect(group.hasSpinner, isTrue);
      });

      test('returns false for success status', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
          response: TestData.createResponseEvent(),
        );
        expect(group.hasSpinner, isFalse);
      });

      test('returns false for error status', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          error: TestData.createErrorEvent(),
        );
        expect(group.hasSpinner, isFalse);
      });

      test('returns false for streamComplete status', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(),
          streamEnd: TestData.createStreamEndEvent(),
        );
        expect(group.hasSpinner, isFalse);
      });
    });

    group('hasEvents', () {
      test('returns false when no events', () {
        final group = HttpEventGroup(requestId: 'req-1');
        expect(group.hasEvents, isFalse);
      });

      test('returns true when has request', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
        );
        expect(group.hasEvents, isTrue);
      });

      test('returns true when has response', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          response: TestData.createResponseEvent(),
        );
        expect(group.hasEvents, isTrue);
      });

      test('returns true when has error', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          error: TestData.createErrorEvent(),
        );
        expect(group.hasEvents, isTrue);
      });

      test('returns true when has streamStart', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(),
        );
        expect(group.hasEvents, isTrue);
      });

      test('returns true when has streamEnd', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamEnd: TestData.createStreamEndEvent(),
        );
        expect(group.hasEvents, isTrue);
      });
    });

    group('statusDescription', () {
      test('returns pending for pending status', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
        );
        expect(group.statusDescription, 'pending');
      });

      test('returns success with status code for success', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
          response: TestData.createResponseEvent(statusCode: 201),
        );
        expect(group.statusDescription, 'success, status 201');
      });

      test('returns client error with status code', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
          response: TestData.createResponseEvent(statusCode: 404),
        );
        expect(group.statusDescription, 'client error, status 404');
      });

      test('returns server error with status code', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(),
          response: TestData.createResponseEvent(statusCode: 500),
        );
        expect(group.statusDescription, 'server error, status 500');
      });

      test('returns network error with exception type', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          error: TestData.createErrorEvent(),
        );
        expect(group.statusDescription, 'network error, NetworkException');
      });

      test('returns streaming for active stream', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(),
        );
        expect(group.statusDescription, 'streaming');
      });

      test('returns stream complete for completed stream', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(),
          streamEnd: TestData.createStreamEndEvent(),
        );
        expect(group.statusDescription, 'stream complete');
      });

      test('returns stream error for failed stream', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(),
          streamEnd: TestData.createStreamEndEvent(
            error: const NetworkException(message: 'Lost'),
          ),
        );
        expect(group.statusDescription, 'stream error');
      });
    });

    group('formatBody', () {
      test('returns empty string for null', () {
        expect(HttpEventGroup.formatBody(null), '');
      });

      test('returns string as-is when not JSON', () {
        expect(HttpEventGroup.formatBody('plain text'), 'plain text');
      });

      test('pretty prints JSON string', () {
        const json = '{"name":"test","value":123}';
        final result = HttpEventGroup.formatBody(json);
        expect(result, contains('"name": "test"'));
        expect(result, contains('"value": 123'));
      });

      test('pretty prints Map', () {
        final map = {'name': 'test', 'value': 123};
        final result = HttpEventGroup.formatBody(map);
        expect(result, contains('"name": "test"'));
        expect(result, contains('"value": 123'));
      });

      test('pretty prints List', () {
        final list = [1, 2, 3];
        final result = HttpEventGroup.formatBody(list);
        expect(result, '[\n  1,\n  2,\n  3\n]');
      });

      test('handles nested structures', () {
        final nested = {
          'user': {'name': 'Alice', 'age': 30},
        };
        final result = HttpEventGroup.formatBody(nested);
        expect(result, contains('"user"'));
        expect(result, contains('"name": "Alice"'));
      });

      test('returns toString for non-JSON-encodable objects', () {
        final obj = DateTime(2024);
        final result = HttpEventGroup.formatBody(obj);
        expect(result, obj.toString());
      });
    });

    group('requestHeaders', () {
      test('returns headers from request event', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(
            headers: const {'Content-Type': 'application/json'},
          ),
        );
        expect(group.requestHeaders, {'Content-Type': 'application/json'});
      });

      test('returns headers from streamStart when no request', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(
            headers: const {'Accept': 'text/event-stream'},
          ),
        );
        expect(group.requestHeaders, {'Accept': 'text/event-stream'});
      });

      test('prefers request over streamStart', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(
            headers: const {'From': 'request'},
          ),
          streamStart: TestData.createStreamStartEvent(
            headers: const {'From': 'streamStart'},
          ),
        );
        expect(group.requestHeaders, {'From': 'request'});
      });

      test('returns empty map when no headers available', () {
        final group = HttpEventGroup(requestId: 'req-1');
        expect(group.requestHeaders, isEmpty);
      });
    });

    group('requestBody', () {
      test('returns body from request event', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: HttpRequestEvent(
            requestId: 'req-1',
            timestamp: DateTime.now(),
            method: 'POST',
            uri: Uri.parse('http://example.com/api'),
            body: const {'message': 'hello'},
          ),
        );
        expect(group.requestBody, {'message': 'hello'});
      });

      test('returns body from streamStart when no request', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(
            body: const {'thread_id': 't1'},
          ),
        );
        expect(group.requestBody, {'thread_id': 't1'});
      });

      test('prefers request over streamStart', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: HttpRequestEvent(
            requestId: 'req-1',
            timestamp: DateTime.now(),
            method: 'POST',
            uri: Uri.parse('http://example.com/api'),
            body: 'from request',
          ),
          streamStart: TestData.createStreamStartEvent(body: 'from stream'),
        );
        expect(group.requestBody, 'from request');
      });

      test('returns null when no body available', () {
        final group = HttpEventGroup(requestId: 'req-1');
        expect(group.requestBody, isNull);
      });
    });

    group('toCurl', () {
      test('returns null when no request or streamStart', () {
        final group = HttpEventGroup(requestId: 'req-1');
        expect(group.toCurl(), isNull);
      });

      test('returns null for response-only group', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          response: TestData.createResponseEvent(),
        );
        expect(group.toCurl(), isNull);
      });

      test('generates basic GET request', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(
            uri: Uri.parse('http://example.com/api'),
          ),
        );
        final curl = group.toCurl()!;
        expect(curl, contains("'http://example.com/api'"));
        expect(curl, isNot(contains('-X GET'))); // GET is default
      });

      test('includes method for non-GET requests', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: HttpRequestEvent(
            requestId: 'req-1',
            timestamp: DateTime.now(),
            method: 'POST',
            uri: Uri.parse('http://example.com/api'),
          ),
        );
        final curl = group.toCurl()!;
        expect(curl, contains('-X POST'));
      });

      test('includes headers', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: HttpRequestEvent(
            requestId: 'req-1',
            timestamp: DateTime.now(),
            method: 'GET',
            uri: Uri.parse('http://example.com/api'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );
        final curl = group.toCurl()!;
        expect(curl, contains("-H 'Content-Type: application/json'"));
        expect(curl, contains("-H 'Accept: application/json'"));
      });

      test('includes body for POST requests', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: HttpRequestEvent(
            requestId: 'req-1',
            timestamp: DateTime.now(),
            method: 'POST',
            uri: Uri.parse('http://example.com/api'),
            body: const {'name': 'test'},
          ),
        );
        final curl = group.toCurl()!;
        expect(curl, contains('-d'));
        expect(curl, contains('"name":"test"'));
      });

      test('escapes single quotes in values', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: HttpRequestEvent(
            requestId: 'req-1',
            timestamp: DateTime.now(),
            method: 'POST',
            uri: Uri.parse('http://example.com/api'),
            body: "it's a test",
          ),
        );
        final curl = group.toCurl()!;
        expect(curl, contains(r"it'\''s a test"));
      });

      test('URL is last', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: HttpRequestEvent(
            requestId: 'req-1',
            timestamp: DateTime.now(),
            method: 'POST',
            uri: Uri.parse('http://example.com/api'),
            headers: const {'X-Custom': 'value'},
            body: 'data',
          ),
        );
        final curl = group.toCurl()!;
        expect(curl.trim().endsWith("'http://example.com/api'"), isTrue);
      });

      test('generates curl for SSE stream start', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(
            method: 'POST',
            uri: Uri.parse('http://example.com/api/runs'),
            headers: const {'Accept': 'text/event-stream'},
            body: const {'thread_id': 'thread-1'},
          ),
        );
        final curl = group.toCurl()!;
        expect(curl, contains('curl'));
        expect(curl, contains('-X POST'));
        expect(curl, contains("-H 'Accept: text/event-stream'"));
        expect(curl, contains('"thread_id":"thread-1"'));
        expect(curl, contains("'http://example.com/api/runs'"));
      });

      test('SSE curl with string body', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          streamStart: TestData.createStreamStartEvent(
            method: 'POST',
            body: 'raw string body',
          ),
        );
        final curl = group.toCurl()!;
        expect(curl, contains("-d 'raw string body'"));
      });

      test('escapes single quotes in URL', () {
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: TestData.createRequestEvent(
            uri: Uri.parse("http://example.com/api?q=it's"),
          ),
        );
        final curl = group.toCurl()!;
        // URL should be escaped: it's -> it'\''s
        expect(curl, contains(r"it'\''s"));
      });
    });

    group('copyWith', () {
      test('preserves requestId', () {
        final group = HttpEventGroup(requestId: 'req-1');
        final copy = group.copyWith();
        expect(copy.requestId, 'req-1');
      });

      test('updates request', () {
        final group = HttpEventGroup(requestId: 'req-1');
        final request = TestData.createRequestEvent();
        final copy = group.copyWith(request: request);
        expect(copy.request, request);
      });

      test('updates response', () {
        final group = HttpEventGroup(requestId: 'req-1');
        final response = TestData.createResponseEvent();
        final copy = group.copyWith(response: response);
        expect(copy.response, response);
      });

      test('updates error', () {
        final group = HttpEventGroup(requestId: 'req-1');
        final error = TestData.createErrorEvent();
        final copy = group.copyWith(error: error);
        expect(copy.error, error);
      });

      test('updates streamStart', () {
        final group = HttpEventGroup(requestId: 'req-1');
        final streamStart = TestData.createStreamStartEvent();
        final copy = group.copyWith(streamStart: streamStart);
        expect(copy.streamStart, streamStart);
      });

      test('updates streamEnd', () {
        final group = HttpEventGroup(requestId: 'req-1');
        final streamEnd = TestData.createStreamEndEvent();
        final copy = group.copyWith(streamEnd: streamEnd);
        expect(copy.streamEnd, streamEnd);
      });

      test('preserves existing values when not specified', () {
        final request = TestData.createRequestEvent();
        final response = TestData.createResponseEvent();
        final group = HttpEventGroup(
          requestId: 'req-1',
          request: request,
          response: response,
        );

        final error = TestData.createErrorEvent();
        final copy = group.copyWith(error: error);

        expect(copy.request, request);
        expect(copy.response, response);
        expect(copy.error, error);
      });
    });
  });
}
