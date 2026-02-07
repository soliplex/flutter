import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:soliplex_logging/src/sinks/disk_queue_io.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sanitizer_integ_test_');
    LogManager.instance.reset();
  });

  tearDown(() async {
    LogManager.instance.reset();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('PII is redacted in HTTP payload', () async {
    final requests = <http.Request>[];
    final client = http_testing.MockClient((request) async {
      requests.add(request);
      return http.Response('', 200);
    });

    final diskQueue = PlatformDiskQueue(directoryPath: tempDir.path);
    final backendSink = BackendLogSink(
      endpoint: 'https://api.example.com/logs',
      client: client,
      installId: 'install-san',
      sessionId: 'session-san',
      diskQueue: diskQueue,
      flushInterval: const Duration(hours: 1),
    );

    LogManager.instance
      ..sanitizer = LogSanitizer()
      ..addSink(backendSink);

    LogManager.instance.getLogger('Auth').info(
      'Login from user@example.com at 192.168.1.1',
      attributes: const {
        'password': 'super-secret-123',
        'username': 'alice',
      },
    );

    await backendSink.flush();
    await backendSink.close();

    expect(requests, hasLength(1));
    final body = jsonDecode(requests.first.body) as Map<String, Object?>;
    final logs = body['logs']! as List;
    final log = logs[0] as Map<String, Object?>;

    // Message should have email and IP redacted.
    final message = log['message']! as String;
    expect(message, isNot(contains('user@example.com')));
    expect(message, isNot(contains('192.168.1.1')));
    expect(message, contains('[REDACTED]'));

    // Password attribute should be redacted.
    final attrs = log['attributes']! as Map<String, Object?>;
    expect(attrs['password'], '[REDACTED]');
    // Non-sensitive attribute preserved.
    expect(attrs['username'], 'alice');
  });
}
