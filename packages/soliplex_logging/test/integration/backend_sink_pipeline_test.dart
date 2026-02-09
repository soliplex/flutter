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

  tearDown(() {
    LogManager.instance.reset();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('full pipeline: Logger → LogManager → BackendLogSink → HTTP', () async {
    final captured = <http.Request>[];
    final mockClient = http_testing.MockClient((request) async {
      captured.add(request);
      return http.Response('', 200);
    });

    final diskQueue = PlatformDiskQueue(directoryPath: tempDir.path);
    final sink = BackendLogSink(
      endpoint: 'https://api.example.com/logs',
      client: mockClient,
      installId: 'i-1',
      sessionId: 's-1',
      diskQueue: diskQueue,
      userId: 'u-1',
      flushInterval: const Duration(hours: 1),
    );

    LogManager.instance
      ..minimumLevel = LogLevel.trace
      ..addSink(sink);

    LogManager.instance.getLogger('Integration')
      ..info('Hello from pipeline', attributes: {'view': 'home'})
      ..warning('Something suspect');

    await LogManager.instance.flush();

    expect(captured, hasLength(1));
    final body = jsonDecode(captured.first.body) as Map<String, Object?>;
    final logs = body['logs']! as List;
    expect(logs, hasLength(2));

    final first = logs[0] as Map<String, Object?>;
    expect(first['message'], 'Hello from pipeline');
    expect(first['level'], 'info');
    expect(first['logger'], 'Integration');
    expect(first['installId'], 'i-1');
    expect(
      (first['attributes']! as Map<String, Object?>)['view'],
      'home',
    );

    final second = logs[1] as Map<String, Object?>;
    expect(second['message'], 'Something suspect');
    expect(second['level'], 'warning');

    await sink.close();
  });

  test('crash recovery: records persist across instances', () async {
    final captured = <http.Request>[];
    final mockClient = http_testing.MockClient((request) async {
      captured.add(request);
      return http.Response('', 200);
    });

    // Simulate crash: write directly to DiskQueue then close it,
    // bypassing BackendLogSink.close() which would flush.
    final queue1 = PlatformDiskQueue(directoryPath: tempDir.path);
    await queue1.append({
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'level': 'info',
      'logger': 'Test',
      'message': 'Before crash',
      'attributes': <String, Object?>{},
      'installId': 'i-1',
      'sessionId': 's-1',
    });
    await queue1.close();

    // New instance picks up pending records.
    final queue2 = PlatformDiskQueue(directoryPath: tempDir.path);
    final sink2 = BackendLogSink(
      endpoint: 'https://api.example.com/logs',
      client: mockClient,
      installId: 'i-1',
      sessionId: 's-2',
      diskQueue: queue2,
      flushInterval: const Duration(hours: 1),
    );
    await sink2.flush();

    expect(captured, hasLength(1));
    final body = jsonDecode(captured.first.body) as Map<String, Object?>;
    final logs = body['logs']! as List;
    expect(logs, hasLength(1));
    expect((logs[0] as Map<String, Object?>)['message'], 'Before crash');

    await sink2.close();
  });
}
