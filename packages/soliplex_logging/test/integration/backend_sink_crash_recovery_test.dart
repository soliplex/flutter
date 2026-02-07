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
    tempDir = Directory.systemTemp.createTempSync('crash_recovery_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('pending records survive crash and send on next launch', () async {
    // Phase 1: Write records, then "crash" (close without flush).
    final queue1 = PlatformDiskQueue(directoryPath: tempDir.path);
    final noopClient = http_testing.MockClient(
      (_) async => http.Response('', 200),
    );
    final sink1 = BackendLogSink(
      endpoint: 'https://api.example.com/logs',
      client: noopClient,
      installId: 'install-crash',
      sessionId: 'session-1',
      diskQueue: queue1,
      // Use jwtProvider returning null so flush skips HTTP during write.
      jwtProvider: () => null,
      flushInterval: const Duration(hours: 1),
    )
      ..write(
        LogRecord(
          level: LogLevel.info,
          message: 'Before crash',
          timestamp: DateTime.utc(2026, 2, 6),
          loggerName: 'App',
          attributes: const {'phase': 'startup'},
        ),
      )
      ..write(
        LogRecord(
          level: LogLevel.warning,
          message: 'Connection lost',
          timestamp: DateTime.utc(2026, 2, 6, 0, 1),
          loggerName: 'Network',
        ),
      );

    // Wait for writes to complete, then simulate crash.
    await sink1.flush(); // Skips because jwt is null, but awaits writes.
    await queue1.close();
    // sink1 is now "dead" (simulating crash).

    // Phase 2: New app launch — new sink with same directory.
    final requests = <http.Request>[];
    final client2 = http_testing.MockClient((request) async {
      requests.add(request);
      return http.Response('', 200);
    });

    final queue2 = PlatformDiskQueue(directoryPath: tempDir.path);
    final sink2 = BackendLogSink(
      endpoint: 'https://api.example.com/logs',
      client: client2,
      installId: 'install-crash',
      sessionId: 'session-2',
      diskQueue: queue2,
      flushInterval: const Duration(hours: 1),
    );

    await sink2.flush();
    await sink2.close();

    // Verify the pre-crash records were sent.
    expect(requests, hasLength(1));
    final body = jsonDecode(requests.first.body) as Map<String, Object?>;
    final logs = body['logs']! as List;
    expect(logs, hasLength(2));
    expect(
      (logs[0] as Map<String, Object?>)['message'],
      'Before crash',
    );
    expect(
      (logs[1] as Map<String, Object?>)['message'],
      'Connection lost',
    );
  });
}
