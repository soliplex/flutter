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
/// - [expectNoLog] — negative assertion (log must NOT exist)
/// - [expectNoErrors] — error sentinel across all loggers
/// - [expectNoHttpErrors] — HTTP-specific error audit
/// - [measureLogDelta] — time between two log events
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

  /// Assert that a log record does NOT exist in the buffer.
  ///
  /// Use for negative assertions — proving something didn't happen.
  /// For example, `expectNoLog('Auth', 'restore')` proves the
  /// `PreAuthenticatedNotifier` skipped the restore path.
  void expectNoLog(String loggerName, String messagePattern) {
    final found = sink.records.any(
      (r) => r.loggerName == loggerName && r.message.contains(messagePattern),
    );
    if (found) {
      dumpLogs(last: 30);
      fail('Unexpected log found: [$loggerName] containing "$messagePattern"');
    }
  }

  /// Assert no unexpected error-level logs exist across all loggers.
  ///
  /// Call in every test's `finally` block to catch silent failures.
  /// Use [allowedPatterns] to suppress known acceptable errors
  /// (e.g., keychain unavailable in debug builds).
  void expectNoErrors({List<String> allowedPatterns = const []}) {
    final errors = sink.records
        .where((r) => r.level >= LogLevel.error)
        .where((r) => !allowedPatterns.any((p) => r.message.contains(p)))
        .toList();
    if (errors.isNotEmpty) {
      dumpLogs(last: 50);
      fail(
        '${errors.length} unexpected error(s):\n'
        '${errors.map((r) => '  [${r.loggerName}] ${r.message}').join('\n')}',
      );
    }
  }

  /// Assert no unexpected HTTP error responses during a test.
  ///
  /// Checks for HTTP status codes >= 400 in logs. Use [allowedStatuses]
  /// to permit expected errors (e.g., 404 for optional endpoints).
  void expectNoHttpErrors({List<int> allowedStatuses = const []}) {
    final httpErrors = sink.records.where((r) {
      if (r.loggerName != 'HTTP') return false;
      final match = _httpStatusPattern.firstMatch(r.message);
      if (match == null) return false;
      final status = int.parse(match.group(1)!);
      return status >= 400 && !allowedStatuses.contains(status);
    }).toList();
    if (httpErrors.isNotEmpty) {
      dumpLogs(last: 50);
      fail(
        '${httpErrors.length} unexpected HTTP error(s):\n'
        '${httpErrors.map((r) => '  ${r.message}').join('\n')}',
      );
    }
  }

  static final _httpStatusPattern = RegExp(r'HTTP (\d{3})');

  /// Measure the time between two log events.
  ///
  /// Returns the [Duration] between the first record matching
  /// [startLogger]/[startPattern] and the first matching
  /// [endLogger]/[endPattern]. Fails if either record is not found.
  Duration measureLogDelta(
    String startLogger,
    String startPattern,
    String endLogger,
    String endPattern,
  ) {
    final records = sink.records;
    LogRecord? start;
    LogRecord? end;
    for (final r in records) {
      if (start == null &&
          r.loggerName == startLogger &&
          r.message.contains(startPattern)) {
        start = r;
      }
      if (r.loggerName == endLogger && r.message.contains(endPattern)) {
        end = r;
      }
    }
    if (start == null) {
      dumpLogs(last: 30);
      fail('Start log not found: [$startLogger] "$startPattern"');
    }
    if (end == null) {
      dumpLogs(last: 30);
      fail('End log not found: [$endLogger] "$endPattern"');
    }
    return end.timestamp.difference(start.timestamp);
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
