import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:soliplex_logging/src/sinks/log_format.dart';
import 'package:test/test.dart';

void main() {
  group('formatLogMessage', () {
    test('formats basic message with level and logger name', () {
      final record = LogRecord(
        level: LogLevel.info,
        message: 'Hello world',
        timestamp: DateTime.now(),
        loggerName: 'TestLogger',
      );

      final result = formatLogMessage(record);

      expect(result, '[INFO] TestLogger: Hello world');
    });

    test('formats message for each log level', () {
      final now = DateTime.now();

      expect(
        formatLogMessage(
          LogRecord(
            level: LogLevel.trace,
            message: 'msg',
            timestamp: now,
            loggerName: 'L',
          ),
        ),
        '[TRACE] L: msg',
      );

      expect(
        formatLogMessage(
          LogRecord(
            level: LogLevel.debug,
            message: 'msg',
            timestamp: now,
            loggerName: 'L',
          ),
        ),
        '[DEBUG] L: msg',
      );

      expect(
        formatLogMessage(
          LogRecord(
            level: LogLevel.info,
            message: 'msg',
            timestamp: now,
            loggerName: 'L',
          ),
        ),
        '[INFO] L: msg',
      );

      expect(
        formatLogMessage(
          LogRecord(
            level: LogLevel.warning,
            message: 'msg',
            timestamp: now,
            loggerName: 'L',
          ),
        ),
        '[WARNING] L: msg',
      );

      expect(
        formatLogMessage(
          LogRecord(
            level: LogLevel.error,
            message: 'msg',
            timestamp: now,
            loggerName: 'L',
          ),
        ),
        '[ERROR] L: msg',
      );

      expect(
        formatLogMessage(
          LogRecord(
            level: LogLevel.fatal,
            message: 'msg',
            timestamp: now,
            loggerName: 'L',
          ),
        ),
        '[FATAL] L: msg',
      );
    });

    test('includes traceId when present', () {
      final record = LogRecord(
        level: LogLevel.info,
        message: 'traced',
        timestamp: DateTime.now(),
        loggerName: 'Test',
        traceId: 'trace-123',
      );

      final result = formatLogMessage(record);

      expect(result, '[INFO] Test: traced (trace=trace-123)');
    });

    test('includes spanId when present', () {
      final record = LogRecord(
        level: LogLevel.info,
        message: 'spanned',
        timestamp: DateTime.now(),
        loggerName: 'Test',
        spanId: 'span-456',
      );

      final result = formatLogMessage(record);

      expect(result, '[INFO] Test: spanned (span=span-456)');
    });

    test('includes both traceId and spanId when present', () {
      final record = LogRecord(
        level: LogLevel.info,
        message: 'full context',
        timestamp: DateTime.now(),
        loggerName: 'Test',
        traceId: 'trace-123',
        spanId: 'span-456',
      );

      final result = formatLogMessage(record);

      expect(
        result,
        '[INFO] Test: full context (trace=trace-123, span=span-456)',
      );
    });

    test('does not include error in message (handled by platform)', () {
      final record = LogRecord(
        level: LogLevel.error,
        message: 'error occurred',
        timestamp: DateTime.now(),
        loggerName: 'Test',
        error: Exception('test error'),
        stackTrace: StackTrace.current,
      );

      final result = formatLogMessage(record);

      // Error and stackTrace should NOT be in the formatted message
      // They are handled separately by each platform
      expect(result, '[ERROR] Test: error occurred');
      expect(result, isNot(contains('Exception')));
    });

    test('handles empty message', () {
      final record = LogRecord(
        level: LogLevel.debug,
        message: '',
        timestamp: DateTime.now(),
        loggerName: 'Test',
      );

      final result = formatLogMessage(record);

      expect(result, '[DEBUG] Test: ');
    });

    test('handles message with special characters', () {
      final record = LogRecord(
        level: LogLevel.info,
        message: 'Message with "quotes" and \'apostrophes\' and\nnewlines',
        timestamp: DateTime.now(),
        loggerName: 'Test',
      );

      final result = formatLogMessage(record);

      expect(
        result,
        '[INFO] Test: Message with "quotes" and \'apostrophes\' and\nnewlines',
      );
    });
  });
}
