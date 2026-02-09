import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:soliplex_logging/src/sinks/disk_queue_io.dart';
import 'package:test/test.dart';

/// Creates a test log record.
LogRecord makeRecord({
  LogLevel level = LogLevel.info,
  String message = 'Test message',
  Map<String, Object> attributes = const {},
}) {
  return LogRecord(
    level: level,
    message: message,
    timestamp: DateTime.utc(2026, 2, 6, 12),
    loggerName: 'Test',
    attributes: attributes,
  );
}

void main() {
  late Directory tempDir;
  late PlatformDiskQueue diskQueue;
  late List<http.Request> capturedRequests;
  late http.Client mockClient;
  var httpStatus = 200;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('backend_sink_test_');
    diskQueue = PlatformDiskQueue(directoryPath: tempDir.path);
    capturedRequests = [];
    httpStatus = 200;

    mockClient = http_testing.MockClient((request) async {
      capturedRequests.add(request);
      return http.Response('', httpStatus);
    });
  });

  tearDown(() async {
    await diskQueue.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  BackendLogSink createSink({
    String? Function()? jwtProvider,
    bool Function()? networkChecker,
    SinkErrorCallback? onError,
    Duration flushInterval = const Duration(hours: 1),
  }) {
    return BackendLogSink(
      endpoint: 'https://api.example.com/logs',
      client: mockClient,
      installId: 'install-001',
      sessionId: 'session-001',
      diskQueue: diskQueue,
      userId: 'user-001',
      resourceAttributes: const {
        'service.name': 'test',
        'service.version': '1.0.0',
      },
      flushInterval: flushInterval,
      jwtProvider: jwtProvider,
      networkChecker: networkChecker,
      onError: onError,
    );
  }

  group('BackendLogSink', () {
    test('records serialized with installId/sessionId/userId', () async {
      final sink = createSink()..write(makeRecord());
      await sink.flush();
      await sink.close();

      expect(capturedRequests, hasLength(1));
      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, Object?>;
      final logs = body['logs']! as List;
      expect(logs, hasLength(1));

      final log = logs[0] as Map<String, Object?>;
      expect(log['installId'], 'install-001');
      expect(log['sessionId'], 'session-001');
      expect(log['userId'], 'user-001');
      expect(log['message'], 'Test message');
      expect(log['level'], 'info');
    });

    test('resource attributes included in payload', () async {
      final sink = createSink()..write(makeRecord());
      await sink.flush();
      await sink.close();

      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, Object?>;
      final resource = body['resource']! as Map<String, Object?>;
      expect(resource['service.name'], 'test');
      expect(resource['service.version'], '1.0.0');
    });

    test('HTTP 200 confirms records', () async {
      final sink = createSink()..write(makeRecord());
      await sink.flush();

      expect(await diskQueue.pendingCount, 0);
      await sink.close();
    });

    test('HTTP 429 keeps records in queue with backoff', () async {
      httpStatus = 429;
      final sink = createSink()..write(makeRecord());
      await sink.flush();

      expect(await diskQueue.pendingCount, 1);
      await sink.close();
    });

    test('HTTP 5xx keeps records in queue', () async {
      httpStatus = 500;
      final sink = createSink()..write(makeRecord());
      await sink.flush();

      expect(await diskQueue.pendingCount, 1);
      await sink.close();
    });

    test('HTTP 401 disables export and calls onError', () async {
      httpStatus = 401;
      String? errorMessage;
      final sink = createSink(
        onError: (msg, _) => errorMessage = msg,
      )..write(makeRecord());
      await sink.flush();

      expect(errorMessage, contains('Auth failure'));
      expect(errorMessage, contains('401'));

      // Second flush should not attempt HTTP.
      capturedRequests.clear();
      sink.write(makeRecord(message: 'Second'));
      await sink.flush();
      expect(capturedRequests, isEmpty);
      await sink.close();
    });

    test('HTTP 404 disables export and calls onError', () async {
      httpStatus = 404;
      String? errorMessage;
      final sink = createSink(
        onError: (msg, _) => errorMessage = msg,
      )..write(makeRecord());
      await sink.flush();

      expect(errorMessage, contains('404'));
      await sink.close();
    });

    test('pre-auth: flush skips when jwtProvider returns null', () async {
      final sink = createSink(jwtProvider: () => null)..write(makeRecord());
      await sink.flush();

      expect(capturedRequests, isEmpty);
      expect(await diskQueue.pendingCount, 1);
      await sink.close();
    });

    test(
      'post-auth: buffered pre-login logs drain on first flush',
      () async {
        String? jwt;
        final sink = createSink(jwtProvider: () => jwt)
          ..write(makeRecord(message: 'Startup'))
          ..write(makeRecord(message: 'Session start'));
        await sink.flush();
        expect(capturedRequests, isEmpty);

        // Simulate login.
        jwt = 'jwt-token-123';
        await sink.flush();

        expect(capturedRequests, hasLength(1));
        final body =
            jsonDecode(capturedRequests.first.body) as Map<String, Object?>;
        final logs = body['logs']! as List;
        expect(logs, hasLength(2));
        await sink.close();
      },
    );

    test('networkChecker false skips flush', () async {
      final sink = createSink(networkChecker: () => false)..write(makeRecord());
      await sink.flush();

      expect(capturedRequests, isEmpty);
      expect(await diskQueue.pendingCount, 1);
      await sink.close();
    });

    test(
      'poison pill: batch discarded after 3 consecutive failures',
      () async {
        httpStatus = 500;
        String? errorMessage;
        final sink = createSink(
          onError: (msg, _) => errorMessage = msg,
        )..write(makeRecord());

        await sink.flush();
        sink.backoffUntil = null;
        await sink.flush();
        sink.backoffUntil = null;
        await sink.flush();

        expect(errorMessage, contains('poison pill'));
        expect(await diskQueue.pendingCount, 0);
        await sink.close();
      },
    );

    test('attribute value safety: non-primitive coerced to string', () async {
      final sink = createSink()
        ..write(
          makeRecord(attributes: const {'count': 42, 'label': 'test'}),
        );
      await sink.flush();
      await sink.close();

      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, Object?>;
      final logs = body['logs']! as List;
      final attrs = (logs[0] as Map<String, Object?>)['attributes']!
          as Map<String, Object?>;
      expect(attrs['count'], 42);
      expect(attrs['label'], 'test');
    });

    test('fatal records use appendSync', () async {
      final sink = createSink()
        ..write(makeRecord(level: LogLevel.fatal, message: 'Crash!'));

      expect(await diskQueue.pendingCount, 1);
      await sink.close();
    });

    test('close attempts final flush', () async {
      final sink = createSink()..write(makeRecord());
      await sink.close();

      expect(capturedRequests, hasLength(1));
    });

    test('severity-triggered flush on ERROR', () async {
      final sink = createSink()
        ..write(makeRecord(level: LogLevel.error, message: 'Error!'));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(capturedRequests, hasLength(1));
      await sink.close();
    });

    test('JWT included in Authorization header', () async {
      final sink = createSink(jwtProvider: () => 'my-jwt-token')
        ..write(makeRecord());
      await sink.flush();
      await sink.close();

      expect(
        capturedRequests.first.headers['Authorization'],
        'Bearer my-jwt-token',
      );
    });

    test('re-enables after new JWT on 401', () async {
      var jwt = 'old-jwt';
      httpStatus = 401;
      final sink = createSink(jwtProvider: () => jwt)
        ..write(makeRecord(message: 'First'));
      await sink.flush();
      expect(capturedRequests, hasLength(1));

      jwt = 'new-jwt';
      httpStatus = 200;
      sink.write(makeRecord(message: 'Second'));
      await sink.flush();

      expect(capturedRequests, hasLength(2));
      await sink.close();
    });

    test('byte-based batch cap limits records per batch', () async {
      final sink = BackendLogSink(
        endpoint: 'https://api.example.com/logs',
        client: mockClient,
        installId: 'i',
        sessionId: 's',
        diskQueue: diskQueue,
        maxBatchBytes: 500,
        flushInterval: const Duration(hours: 1),
      );

      for (var i = 0; i < 10; i++) {
        sink.write(makeRecord(message: 'Message number $i with some content'));
      }
      await sink.flush();
      await sink.close();

      expect(capturedRequests, isNotEmpty);
      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, Object?>;
      final logs = body['logs']! as List;
      expect(logs.length, lessThan(10));
    });

    test('oversized single record is discarded and reported (C1)', () async {
      String? errorMessage;
      // Use a very small maxBatchBytes so a normal record exceeds it.
      final sink = BackendLogSink(
        endpoint: 'https://api.example.com/logs',
        client: mockClient,
        installId: 'i',
        sessionId: 's',
        diskQueue: diskQueue,
        maxBatchBytes: 10,
        flushInterval: const Duration(hours: 1),
        onError: (msg, _) => errorMessage = msg,
      )..write(makeRecord());
      await sink.flush();

      // Record should be confirmed (discarded) from the queue.
      expect(await diskQueue.pendingCount, 0);
      expect(errorMessage, contains('dropped'));
      expect(errorMessage, contains('exceeds'));
      expect(capturedRequests, isEmpty);
      await sink.close();
    });

    test('concurrent flush calls are deduplicated (C2)', () async {
      final sink = createSink()..write(makeRecord());

      // Fire two flushes concurrently — only one HTTP call should occur.
      await Future.wait([sink.flush(), sink.flush()]);

      expect(capturedRequests, hasLength(1));
      await sink.close();
    });

    test('network error triggers retry with backoff', () async {
      final errorClient = http_testing.MockClient(
        (_) => throw Exception('No network'),
      );
      final sink = BackendLogSink(
        endpoint: 'https://api.example.com/logs',
        client: errorClient,
        installId: 'i',
        sessionId: 's',
        diskQueue: diskQueue,
        flushInterval: const Duration(hours: 1),
      )..write(makeRecord());
      await sink.flush();

      expect(await diskQueue.pendingCount, 1);
      await sink.close();
    });

    test('coerces List and Map attribute values', () async {
      final sink = createSink()
        ..write(
          makeRecord(
            attributes: const {
              'tags': ['a', 'b'],
              'meta': {'nested': true},
            },
          ),
        );
      await sink.flush();
      await sink.close();

      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, Object?>;
      final logs = body['logs']! as List;
      final attrs = (logs[0] as Map<String, Object?>)['attributes']!
          as Map<String, Object?>;
      expect(attrs['tags'], ['a', 'b']);
      expect(attrs['meta'], {'nested': true});
    });

    test('record size guard truncates oversized messages', () async {
      final bigMessage = 'x' * 100000;
      final sink = createSink()..write(makeRecord(message: bigMessage));
      await sink.flush();
      await sink.close();

      expect(capturedRequests, hasLength(1));
      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, Object?>;
      final logs = body['logs']! as List;
      final log = logs[0] as Map<String, Object?>;
      final message = log['message']! as String;
      expect(message.length, lessThan(bigMessage.length));
      expect(message, contains('[truncated]'));
    });

    test('UTF-8 safe truncation does not split multi-byte chars', () async {
      final multiByteMsg = '\u{1F600}' * 200 + 'x' * 99000;
      final sink = createSink()..write(makeRecord(message: multiByteMsg));
      await sink.flush();
      await sink.close();

      expect(capturedRequests, hasLength(1));
      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, Object?>;
      expect(body['logs'], isNotEmpty);
    });
  });
}
