import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

/// Logging-aware test harness for Patrol E2E tests.
///
/// Provides:
/// - [prefs] and [sink] for constructing provider overrides
/// - [waitForLog] — stream-based wait for internal log events
/// - [expectLog] — synchronous assertion on past log records
/// - [dumpLogs] — dump recent logs to console on failure
class TestLogHarness {
  late final MemorySink sink;
  late final SharedPreferences prefs;

  /// Initialize logging subsystem.
  ///
  /// After calling, use [prefs] and [sink] to construct provider overrides:
  /// ```dart
  /// preloadedPrefsProvider.overrideWithValue(harness.prefs),
  /// memorySinkProvider.overrideWithValue(harness.sink),
  /// ```
  Future<void> initialize() async {
    SharedPreferences.setMockInitialValues({
      'log_level': 0, // LogLevel.trace
      'console_logging': true,
      'stdout_logging': true,
    });
    prefs = await SharedPreferences.getInstance();

    sink = MemorySink(maxRecords: 5000);
    LogManager.instance.addSink(sink);
    LogManager.instance.minimumLevel = LogLevel.trace;
  }

  /// Wait for a specific log to appear (stream-based, replaces polling).
  ///
  /// Checks existing records first, then subscribes to the stream.
  Future<void> waitForLog(
    String loggerName,
    String messagePattern, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final found = sink.records.any(
      (r) => r.loggerName == loggerName && r.message.contains(messagePattern),
    );
    if (found) return;

    try {
      await sink.onRecord
          .firstWhere(
            (r) =>
                r.loggerName == loggerName &&
                r.message.contains(messagePattern),
          )
          .timeout(timeout);
    } on TimeoutException {
      dumpLogs(last: 50);
      fail('Timed out waiting for [$loggerName] "$messagePattern"');
    }
  }

  /// Assert a log record already exists in the buffer.
  void expectLog(String loggerName, String messagePattern) {
    final found = sink.records.any(
      (r) => r.loggerName == loggerName && r.message.contains(messagePattern),
    );
    if (!found) {
      dumpLogs(last: 30);
      fail('Log not found: [$loggerName] containing "$messagePattern"');
    }
  }

  /// Dump recent logs to console (for failure diagnostics).
  void dumpLogs({int last = 100}) {
    final records = sink.records;
    final start = records.length > last ? records.length - last : 0;
    debugPrint('\n=== TEST LOG DUMP (last $last of ${records.length}) ===');
    for (var i = start; i < records.length; i++) {
      debugPrint(records[i].toString());
    }
    debugPrint('=== END LOG DUMP ===\n');
  }

  /// Clean up after test.
  void dispose() {
    LogManager.instance.removeSink(sink);
    sink.close();
  }
}
