import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:soliplex_logging/src/sinks/disk_queue_io.dart';
import 'package:test/test.dart';

LogRecord makeRecord({
  LogLevel level = LogLevel.info,
  String message = 'Test message',
  String loggerName = 'Test',
  Map<String, Object> attributes = const {},
}) {
  return LogRecord(
    level: level,
    message: message,
    timestamp: DateTime.utc(2026, 2, 6, 12),
    loggerName: loggerName,
    attributes: attributes,
  );
}

void main() {
  late Directory tempDir;
  late PlatformDiskQueue diskQueue;
  late List<http.Request> capturedRequests;
  late http.Client mockClient;
  late MemorySink memorySink;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('breadcrumb_test_');
    diskQueue = PlatformDiskQueue(directoryPath: tempDir.path);
    capturedRequests = [];
    memorySink = MemorySink(maxRecords: 100);

    mockClient = http_testing.MockClient((request) async {
      capturedRequests.add(request);
      return http.Response('', 200);
    });
  });

  tearDown(() async {
    await diskQueue.close();
    await memorySink.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  BackendLogSink createSink({MemorySink? overrideMemory}) {
    return BackendLogSink(
      endpoint: 'https://api.example.com/logs',
      client: mockClient,
      installId: 'install-001',
      sessionId: 'session-001',
      diskQueue: diskQueue,
      memorySink: overrideMemory ?? memorySink,
      flushInterval: const Duration(hours: 1),
    );
  }

  List<Object?> extractBreadcrumbs(List<http.Request> requests) {
    final body = jsonDecode(requests.last.body) as Map<String, Object?>;
    final logs = body['logs']! as List;
    final log = logs.last! as Map<String, Object?>;
    return log['breadcrumbs'] as List<Object?>? ?? [];
  }

  group('BackendLogSink breadcrumbs', () {
    test('ERROR log attaches last 20 breadcrumbs from MemorySink', () async {
      final sink = createSink();

      // Write 25 records to MemorySink.
      for (var i = 0; i < 25; i++) {
        memorySink.write(makeRecord(message: 'breadcrumb $i'));
      }

      // Write an ERROR record to the backend sink.
      sink.write(makeRecord(level: LogLevel.error, message: 'Boom'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final breadcrumbs = extractBreadcrumbs(capturedRequests);
      expect(breadcrumbs, hasLength(20));

      // Verify it's the last 20 (indices 5–24).
      final first = (breadcrumbs.first! as Map<String, Object?>)['message'];
      expect(first, 'breadcrumb 5');
      final last = (breadcrumbs.last! as Map<String, Object?>)['message'];
      expect(last, 'breadcrumb 24');
      await sink.close();
    });

    test('FATAL log attaches breadcrumbs', () async {
      final sink = createSink();

      memorySink
        ..write(makeRecord(message: 'step 1'))
        ..write(makeRecord(message: 'step 2'));

      sink.write(makeRecord(level: LogLevel.fatal, message: 'Fatal!'));
      await sink.flush();
      await sink.close();

      final breadcrumbs = extractBreadcrumbs(capturedRequests);
      expect(breadcrumbs, hasLength(2));
    });

    test('INFO log does not attach breadcrumbs', () async {
      final sink = createSink();

      memorySink.write(makeRecord(message: 'some context'));
      sink.write(makeRecord(message: 'Normal info'));
      await sink.flush();
      await sink.close();

      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, Object?>;
      final logs = body['logs']! as List;
      final log = logs[0]! as Map<String, Object?>;
      expect(log.containsKey('breadcrumbs'), isFalse);
    });

    test('category derived from loggerName: Router → ui', () async {
      final sink = createSink();

      memorySink.write(makeRecord(loggerName: 'Router.Home'));
      sink.write(makeRecord(level: LogLevel.error, message: 'Err'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final breadcrumbs = extractBreadcrumbs(capturedRequests);
      final bc = breadcrumbs[0]! as Map<String, Object?>;
      expect(bc['category'], 'ui');
      await sink.close();
    });

    test('category derived from loggerName: Http → network', () async {
      final sink = createSink();

      memorySink.write(makeRecord(loggerName: 'Http.Client'));
      sink.write(makeRecord(level: LogLevel.error, message: 'Err'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final breadcrumbs = extractBreadcrumbs(capturedRequests);
      final bc = breadcrumbs[0]! as Map<String, Object?>;
      expect(bc['category'], 'network');
      await sink.close();
    });

    test('category derived from loggerName: Lifecycle → system', () async {
      final sink = createSink();

      memorySink.write(makeRecord(loggerName: 'Lifecycle'));
      sink.write(makeRecord(level: LogLevel.error, message: 'Err'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final breadcrumbs = extractBreadcrumbs(capturedRequests);
      final bc = breadcrumbs[0]! as Map<String, Object?>;
      expect(bc['category'], 'system');
      await sink.close();
    });

    test('category derived from loggerName: Auth → user', () async {
      final sink = createSink();

      memorySink.write(makeRecord(loggerName: 'Auth'));
      sink.write(makeRecord(level: LogLevel.error, message: 'Err'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final breadcrumbs = extractBreadcrumbs(capturedRequests);
      final bc = breadcrumbs[0]! as Map<String, Object?>;
      expect(bc['category'], 'user');
      await sink.close();
    });

    test('explicit breadcrumb_category attribute overrides derived', () async {
      final sink = createSink();

      memorySink.write(
        makeRecord(
          loggerName: 'Router.Home',
          attributes: const {'breadcrumb_category': 'network'},
        ),
      );
      sink.write(makeRecord(level: LogLevel.error, message: 'Err'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final breadcrumbs = extractBreadcrumbs(capturedRequests);
      final bc = breadcrumbs[0]! as Map<String, Object?>;
      expect(bc['category'], 'network');
      await sink.close();
    });

    test('fewer than 20 records in MemorySink → all attached', () async {
      final sink = createSink();

      for (var i = 0; i < 5; i++) {
        memorySink.write(makeRecord(message: 'bc $i'));
      }

      sink.write(makeRecord(level: LogLevel.error, message: 'Err'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final breadcrumbs = extractBreadcrumbs(capturedRequests);
      expect(breadcrumbs, hasLength(5));
      await sink.close();
    });

    test('empty MemorySink → empty breadcrumbs array', () async {
      final sink = createSink()
        ..write(makeRecord(level: LogLevel.error, message: 'Err'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final breadcrumbs = extractBreadcrumbs(capturedRequests);
      expect(breadcrumbs, isEmpty);
      await sink.close();
    });

    test('no memorySink → no breadcrumbs key', () async {
      final sink = BackendLogSink(
        endpoint: 'https://api.example.com/logs',
        client: mockClient,
        installId: 'i',
        sessionId: 's',
        diskQueue: diskQueue,
        flushInterval: const Duration(hours: 1),
      )..write(makeRecord(level: LogLevel.error, message: 'Err'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final body =
          jsonDecode(capturedRequests.first.body) as Map<String, Object?>;
      final logs = body['logs']! as List;
      final log = logs[0]! as Map<String, Object?>;
      expect(log.containsKey('breadcrumbs'), isFalse);
      await sink.close();
    });

    test('unknown loggerName defaults to system category', () async {
      final sink = createSink();

      memorySink.write(makeRecord(loggerName: 'DatabasePool'));
      sink.write(makeRecord(level: LogLevel.error, message: 'Err'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final breadcrumbs = extractBreadcrumbs(capturedRequests);
      final bc = breadcrumbs[0]! as Map<String, Object?>;
      expect(bc['category'], 'system');
      await sink.close();
    });

    test('breadcrumb contains expected fields', () async {
      final sink = createSink();

      memorySink.write(
        makeRecord(
          message: 'Navigate to chat',
          loggerName: 'Router',
        ),
      );
      sink.write(makeRecord(level: LogLevel.error, message: 'Err'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final breadcrumbs = extractBreadcrumbs(capturedRequests);
      final bc = breadcrumbs[0]! as Map<String, Object?>;
      expect(bc['timestamp'], isA<String>());
      expect(bc['level'], 'info');
      expect(bc['logger'], 'Router');
      expect(bc['message'], 'Navigate to chat');
      expect(bc['category'], 'ui');
      await sink.close();
    });
  });

  group('deriveBreadcrumbCategory', () {
    test('Router.* → ui', () {
      final record = makeRecord(loggerName: 'Router.Settings');
      expect(deriveBreadcrumbCategory(record), 'ui');
    });

    test('Navigation → ui', () {
      final record = makeRecord(loggerName: 'Navigation');
      expect(deriveBreadcrumbCategory(record), 'ui');
    });

    test('UI.Button → ui', () {
      final record = makeRecord(loggerName: 'UI.Button');
      expect(deriveBreadcrumbCategory(record), 'ui');
    });

    test('Http.Client → network', () {
      final record = makeRecord(loggerName: 'Http.Client');
      expect(deriveBreadcrumbCategory(record), 'network');
    });

    test('Network → network', () {
      final record = makeRecord(loggerName: 'Network');
      expect(deriveBreadcrumbCategory(record), 'network');
    });

    test('Connectivity.Monitor → network', () {
      final record = makeRecord(loggerName: 'Connectivity.Monitor');
      expect(deriveBreadcrumbCategory(record), 'network');
    });

    test('Lifecycle → system', () {
      final record = makeRecord(loggerName: 'Lifecycle');
      expect(deriveBreadcrumbCategory(record), 'system');
    });

    test('Permission.Camera → system', () {
      final record = makeRecord(loggerName: 'Permission.Camera');
      expect(deriveBreadcrumbCategory(record), 'system');
    });

    test('Auth → user', () {
      final record = makeRecord(loggerName: 'Auth');
      expect(deriveBreadcrumbCategory(record), 'user');
    });

    test('Login.OIDC → user', () {
      final record = makeRecord(loggerName: 'Login.OIDC');
      expect(deriveBreadcrumbCategory(record), 'user');
    });

    test('User.Action → user', () {
      final record = makeRecord(loggerName: 'User.Action');
      expect(deriveBreadcrumbCategory(record), 'user');
    });

    test('unknown logger → system', () {
      final record = makeRecord(loggerName: 'SomeOtherLogger');
      expect(deriveBreadcrumbCategory(record), 'system');
    });

    test('explicit attribute overrides loggerName', () {
      final record = makeRecord(
        loggerName: 'Router',
        attributes: const {'breadcrumb_category': 'network'},
      );
      expect(deriveBreadcrumbCategory(record), 'network');
    });
  });
}
