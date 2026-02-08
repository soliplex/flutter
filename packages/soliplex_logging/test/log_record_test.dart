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
