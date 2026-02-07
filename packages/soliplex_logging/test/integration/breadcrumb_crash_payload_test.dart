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
    tempDir = Directory.systemTemp.createTempSync('breadcrumb_integ_');
    LogManager.instance.reset();
  });

  tearDown(() async {
    LogManager.instance.reset();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    'Log 25 records then ERROR → HTTP payload has 20 breadcrumbs '
    'with correct categories',
    () async {
      final requests = <http.Request>[];
      final client = http_testing.MockClient((request) async {
        requests.add(request);
        return http.Response('', 200);
      });

      final diskQueue = PlatformDiskQueue(directoryPath: tempDir.path);
      final memorySink = MemorySink(maxRecords: 100);

      final backendSink = BackendLogSink(
        endpoint: 'https://api.example.com/logs',
        client: client,
        installId: 'install-integ',
        sessionId: 'session-integ',
        userId: 'user-integ',
        diskQueue: diskQueue,
        memorySink: memorySink,
        resourceAttributes: const {'service.name': 'soliplex-test'},
        flushInterval: const Duration(hours: 1),
      );

      LogManager.instance
        ..addSink(memorySink)
        ..addSink(backendSink);

      // Log 25 records through the Logger API with different loggers.
      final loggers = {
        0: LogManager.instance.getLogger('Router'),
        1: LogManager.instance.getLogger('Http'),
        2: LogManager.instance.getLogger('Auth'),
        3: LogManager.instance.getLogger('App'),
      };

      for (var i = 0; i < 25; i++) {
        loggers[i % 4]!.info('breadcrumb $i');
      }

      // Now log an ERROR.
      LogManager.instance.getLogger('ErrorScope').error(
            'Something went wrong',
          );

      // Let the unawaited flush complete.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // The ERROR record should have been flushed.
      expect(requests, isNotEmpty);

      // Find the request containing the error record.
      Map<String, Object?>? errorLog;
      for (final req in requests) {
        final body = jsonDecode(req.body) as Map<String, Object?>;
        final logs = body['logs']! as List;
        for (final log in logs) {
          final logMap = log! as Map<String, Object?>;
          if (logMap['level'] == 'error') {
            errorLog = logMap;
          }
        }
      }

      expect(errorLog, isNotNull);
      final breadcrumbs = errorLog!['breadcrumbs']! as List;

      // Exactly 20 breadcrumbs (from the 25 + 1 error, last 20 at
      // time of the error write).
      expect(breadcrumbs, hasLength(20));

      // Verify categories are derived correctly.
      final categories = breadcrumbs
          .cast<Map<String, Object?>>()
          .map((b) => b['category']! as String)
          .toSet();
      expect(categories, containsAll(['ui', 'network', 'user', 'system']));

      // Verify breadcrumb structure.
      final firstBc = breadcrumbs.first! as Map<String, Object?>;
      expect(firstBc, containsPair('timestamp', isA<String>()));
      expect(firstBc, containsPair('level', 'info'));
      expect(firstBc, containsPair('logger', isA<String>()));
      expect(firstBc, containsPair('message', isA<String>()));
      expect(firstBc, containsPair('category', isA<String>()));

      await backendSink.close();
      await memorySink.close();
    },
  );
}
