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

    test('stores attributes', () {
      final record = LogRecord(
        level: LogLevel.info,
        message: 'User action',
        timestamp: DateTime.now(),
        loggerName: 'Test',
        attributes: const {'user_id': 'u-42', 'http_status': 200},
      );

      expect(record.attributes, {'user_id': 'u-42', 'http_status': 200});
    });

    test('attributes default to empty map', () {
      final record = LogRecord(
        level: LogLevel.info,
        message: 'Test',
        timestamp: DateTime.now(),
        loggerName: 'Test',
      );

      expect(record.attributes, isEmpty);
    });

    test('toString includes attributes when non-empty', () {
      final record = LogRecord(
        level: LogLevel.info,
        message: 'Test',
        timestamp: DateTime.now(),
        loggerName: 'Test',
        attributes: const {'view_name': 'home'},
      );

      expect(record.toString(), contains('view_name'));
      expect(record.toString(), contains('home'));
    });

    test('toString omits attributes when empty', () {
      final record = LogRecord(
        level: LogLevel.info,
        message: 'Test',
        timestamp: DateTime.now(),
        loggerName: 'Test',
      );

      // Should not contain curly braces from an empty map
      expect(record.toString(), isNot(contains('{}')));
    });

    test('copyWith returns new record with overridden fields', () {
      final original = LogRecord(
        level: LogLevel.info,
        message: 'Original',
        timestamp: DateTime(2024),
        loggerName: 'Test',
        attributes: const {'key': 'value'},
      );

      final copied = original.copyWith(
        message: 'Copied',
        attributes: {'new_key': 'new_value'},
      );

      expect(copied.level, LogLevel.info);
      expect(copied.message, 'Copied');
      expect(copied.loggerName, 'Test');
      expect(copied.attributes, {'new_key': 'new_value'});
      expect(original.message, 'Original');
      expect(original.attributes, {'key': 'value'});
    });

    test('copyWith with no args returns equivalent record', () {
      final original = LogRecord(
        level: LogLevel.warning,
        message: 'Test',
        timestamp: DateTime(2024, 6, 15),
        loggerName: 'Logger',
        spanId: 'span-1',
        traceId: 'trace-1',
        attributes: const {'k': 'v'},
      );

      final copied = original.copyWith();

      expect(copied.level, original.level);
      expect(copied.message, original.message);
      expect(copied.timestamp, original.timestamp);
      expect(copied.loggerName, original.loggerName);
      expect(copied.spanId, original.spanId);
      expect(copied.traceId, original.traceId);
      expect(copied.attributes, original.attributes);
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
