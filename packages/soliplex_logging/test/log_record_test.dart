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

    test('toString includes timestamp and basic info', () {
      final record = LogRecord(
        level: LogLevel.info,
        message: 'Test message',
        timestamp: DateTime(2025, 3, 15, 9, 5, 7, 42),
        loggerName: 'TestLogger',
      );

      final str = record.toString();
      expect(str, startsWith('09:05:07.042 '));
      expect(str, contains('[INFO]'));
      expect(str, contains('TestLogger'));
      expect(str, contains('Test message'));
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

    test('attributes are unmodifiable after construction', () {
      final mutable = {'key': 'original'};
      final record = LogRecord(
        level: LogLevel.info,
        message: 'Test',
        timestamp: DateTime.now(),
        loggerName: 'Test',
        attributes: mutable,
      );

      // Mutating the source map must not affect the record.
      mutable['key'] = 'mutated';
      expect(record.attributes['key'], 'original');

      // Direct mutation of record.attributes must throw.
      expect(
        () => record.attributes['new'] = 'value',
        throwsUnsupportedError,
      );
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

    group('copyWith', () {
      test('returns new record with overridden fields', () {
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

      test('can clear nullable fields by passing null', () {
        final original = LogRecord(
          level: LogLevel.error,
          message: 'Original',
          timestamp: DateTime(2024),
          loggerName: 'Test',
          error: Exception('error'),
          stackTrace: StackTrace.current,
          spanId: 'span-1',
          traceId: 'trace-1',
        );

        final copied = original.copyWith(
          error: null,
          stackTrace: null,
          spanId: null,
          traceId: null,
        );

        expect(original.error, isNotNull);
        expect(original.spanId, isNotNull);
        expect(copied.error, isNull);
        expect(copied.stackTrace, isNull);
        expect(copied.spanId, isNull);
        expect(copied.traceId, isNull);
      });

      test('with no args returns equivalent record', () {
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
