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
    tempDir = Directory.systemTemp.createTempSync('pipeline_test_');
    LogManager.instance.reset();
  });

  tearDown(() async {
    LogManager.instance.reset();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('Logger.info → LogManager → BackendLogSink → HTTP payload', () async {
    final requests = <http.Request>[];
    final client = http_testing.MockClient((request) async {
      requests.add(request);
      return http.Response('', 200);
    });

    final diskQueue = PlatformDiskQueue(directoryPath: tempDir.path);
    final backendSink = BackendLogSink(
      endpoint: 'https://api.example.com/logs',
      client: client,
      installId: 'install-test',
      sessionId: 'session-test',
      userId: 'user-test',
      diskQueue: diskQueue,
      resourceAttributes: const {
        'service.name': 'soliplex-flutter',
        'service.version': '2.0.0',
      },
      flushInterval: const Duration(hours: 1),
    );

    LogManager.instance.addSink(backendSink);

    LogManager.instance.getLogger('Auth').info(
      'User authenticated',
      attributes: const {
        'user_id': 'u-42',
        'method': 'oauth',
      },
    );

    await backendSink.flush();
    await backendSink.close();

    expect(requests, hasLength(1));
    final body = jsonDecode(requests.first.body) as Map<String, Object?>;

    // Verify resource envelope.
    final resource = body['resource']! as Map<String, Object?>;
    expect(resource['service.name'], 'soliplex-flutter');

    // Verify log record.
    final logs = body['logs']! as List;
    expect(logs, hasLength(1));
    final log = logs[0] as Map<String, Object?>;
    expect(log['message'], 'User authenticated');
    expect(log['logger'], 'Auth');
    expect(log['level'], 'info');
    expect(log['installId'], 'install-test');
    expect(log['sessionId'], 'session-test');
    expect(log['userId'], 'user-test');

    final attrs = log['attributes']! as Map<String, Object?>;
    expect(attrs['user_id'], 'u-42');
    expect(attrs['method'], 'oauth');
  });
}
