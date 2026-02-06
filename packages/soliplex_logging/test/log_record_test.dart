import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:test/test.dart';

void main() {
  group('LogRecord', () {
    test('stores required fields', () {
      final timestamp = DateTime(2024, 1, 15, 10, 30);
      final record = LogRecord(
        level: LogLevel.info,
        message: 'Test message',
        timestamp: timestamp,
        loggerName: 'TestLogger',
      );

      expect(record.level, LogLevel.info);
      expect(record.message, 'Test message');
      expect(record.timestamp, timestamp);
      expect(record.loggerName, 'TestLogger');
    });

    test('stores optional error fields', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;
      final record = LogRecord(
        level: LogLevel.error,
        message: 'Error occurred',
        timestamp: DateTime.now(),
        loggerName: 'TestLogger',
        error: error,
        stackTrace: stackTrace,
      );

      expect(record.error, error);
      expect(record.stackTrace, stackTrace);
    });

    test('stores span fields for telemetry', () {
      final record = LogRecord(
        level: LogLevel.info,
        message: 'Request',
        timestamp: DateTime.now(),
        loggerName: 'HTTP',
        spanId: 'span-123',
        traceId: 'trace-456',
      );

      expect(record.spanId, 'span-123');
      expect(record.traceId, 'trace-456');
    });

    test('span fields are nullable', () {
      final record = LogRecord(
        level: LogLevel.info,
        message: 'Test',
        timestamp: DateTime.now(),
        loggerName: 'Test',
      );

      expect(record.spanId, isNull);
      expect(record.traceId, isNull);
    });

    group('hasDetails', () {
      test('is false when no error and no stackTrace', () {
        final record = LogRecord(
          level: LogLevel.info,
          message: 'msg',
          timestamp: DateTime.now(),
          loggerName: 'Test',
        );
        expect(record.hasDetails, isFalse);
      });

      test('is true when error is present', () {
        final record = LogRecord(
          level: LogLevel.error,
          message: 'msg',
          timestamp: DateTime.now(),
          loggerName: 'Test',
          error: Exception('err'),
        );
        expect(record.hasDetails, isTrue);
      });

      test('is true when stackTrace is present', () {
        final record = LogRecord(
          level: LogLevel.warning,
          message: 'msg',
          timestamp: DateTime.now(),
          loggerName: 'Test',
          stackTrace: StackTrace.current,
        );
        expect(record.hasDetails, isTrue);
      });

      test('is true when both error and stackTrace are present', () {
        final record = LogRecord(
          level: LogLevel.error,
          message: 'msg',
          timestamp: DateTime.now(),
          loggerName: 'Test',
          error: Exception('err'),
          stackTrace: StackTrace.current,
        );
        expect(record.hasDetails, isTrue);
      });
    });

    group('formattedTimestamp', () {
      test('formats as HH:mm:ss.mmm', () {
        final record = LogRecord(
          level: LogLevel.info,
          message: 'msg',
          timestamp: DateTime(2025, 3, 15, 9, 5, 7, 42),
          loggerName: 'Test',
        );
        expect(record.formattedTimestamp, '09:05:07.042');
      });

      test('pads single-digit components', () {
        final record = LogRecord(
          level: LogLevel.info,
          message: 'msg',
          timestamp: DateTime(2025, 1, 1, 1, 2, 3, 4),
          loggerName: 'Test',
        );
        expect(record.formattedTimestamp, '01:02:03.004');
      });

      test('formats end of day', () {
        final record = LogRecord(
          level: LogLevel.info,
          message: 'msg',
          timestamp: DateTime(2025, 1, 1, 23, 59, 59, 999),
          loggerName: 'Test',
        );
        expect(record.formattedTimestamp, '23:59:59.999');
      });
    });

    test('toString includes basic info', () {
      final record = LogRecord(
        level: LogLevel.info,
        message: 'Test message',
        timestamp: DateTime.now(),
        loggerName: 'TestLogger',
      );

      expect(record.toString(), contains('[INFO]'));
      expect(record.toString(), contains('TestLogger'));
      expect(record.toString(), contains('Test message'));
    });

    test('toString includes span context when present', () {
      final record = LogRecord(
        level: LogLevel.info,
        message: 'Test',
        timestamp: DateTime.now(),
        loggerName: 'Test',
        spanId: 'span-123',
        traceId: 'trace-456',
      );

      expect(record.toString(), contains('trace=trace-456'));
      expect(record.toString(), contains('span=span-123'));
    });

    test('toString includes error when present', () {
      final record = LogRecord(
        level: LogLevel.error,
        message: 'Failed',
        timestamp: DateTime.now(),
        loggerName: 'Test',
        error: Exception('Something broke'),
      );

      expect(record.toString(), contains('Error:'));
      expect(record.toString(), contains('Something broke'));
    });
  });
}
