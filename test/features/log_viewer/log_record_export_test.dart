import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/features/log_viewer/log_record_export.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

LogRecord _makeRecord({
  LogLevel level = LogLevel.info,
  String message = 'Test message',
  String loggerName = 'Test',
  DateTime? timestamp,
  Object? error,
  StackTrace? stackTrace,
  String? spanId,
  String? traceId,
  Map<String, Object> attributes = const {},
}) {
  return LogRecord(
    level: level,
    message: message,
    loggerName: loggerName,
    timestamp: timestamp ?? DateTime(2024, 1, 15, 10, 30, 45, 123),
    error: error,
    stackTrace: stackTrace,
    spanId: spanId,
    traceId: traceId,
    attributes: attributes,
  );
}

void main() {
  group('LogRecordExport.toExportJson', () {
    test('includes all required fields', () {
      final json = _makeRecord().toExportJson();

      expect(json, containsPair('timestamp', isA<String>()));
      expect(json, containsPair('level', 'info'));
      expect(json, containsPair('logger', 'Test'));
      expect(json, containsPair('message', 'Test message'));
    });

    test('timestamp is UTC ISO8601', () {
      // Use a non-UTC timestamp as input.
      final localTime = DateTime(2024, 6, 15, 14, 30);
      final json = _makeRecord(timestamp: localTime).toExportJson();

      final ts = json['timestamp']! as String;
      expect(ts, endsWith('Z'));
      expect(DateTime.parse(ts).isUtc, isTrue);
      expect(DateTime.parse(ts), equals(localTime.toUtc()));
    });

    test('null optional fields are omitted', () {
      final json = _makeRecord().toExportJson();

      expect(json.containsKey('error'), isFalse);
      expect(json.containsKey('stackTrace'), isFalse);
      expect(json.containsKey('spanId'), isFalse);
      expect(json.containsKey('traceId'), isFalse);
      expect(json.containsKey('attributes'), isFalse);
    });

    test('present optional fields are included', () {
      final json = _makeRecord(
        error: Exception('boom'),
        stackTrace: StackTrace.current,
        spanId: 'span-1',
        traceId: 'trace-1',
      ).toExportJson();

      expect(json.containsKey('error'), isTrue);
      expect(json.containsKey('stackTrace'), isTrue);
      expect(json, containsPair('spanId', 'span-1'));
      expect(json, containsPair('traceId', 'trace-1'));
    });

    test('empty attributes omitted', () {
      final json = _makeRecord().toExportJson();
      expect(json.containsKey('attributes'), isFalse);
    });

    test('attributes with primitives pass through', () {
      final json = _makeRecord(
        attributes: {
          'str': 'hello',
          'int': 42,
          'double': 3.14,
          'bool': true,
        },
      ).toExportJson();

      final attrs = json['attributes']! as Map<String, Object?>;
      expect(attrs['str'], 'hello');
      expect(attrs['int'], 42);
      expect(attrs['double'], 3.14);
      expect(attrs['bool'], true);
    });

    test('attributes with nested maps coerced', () {
      final json = _makeRecord(
        attributes: {
          'nested': <Object, Object>{1: 'one', 'two': 2},
        },
      ).toExportJson();

      final attrs = json['attributes']! as Map<String, Object?>;
      final nested = attrs['nested']! as Map<String, Object?>;
      expect(nested['1'], 'one');
      expect(nested['two'], 2);
    });

    test('attributes with lists coerced', () {
      final json = _makeRecord(
        attributes: {
          'items': [1, 'two', true],
        },
      ).toExportJson();

      final attrs = json['attributes']! as Map<String, Object?>;
      expect(attrs['items'], [1, 'two', true]);
    });

    test('attributes with custom objects use toString', () {
      final json = _makeRecord(
        attributes: {
          'uri': Uri.parse('https://example.com'),
        },
      ).toExportJson();

      final attrs = json['attributes']! as Map<String, Object?>;
      expect(attrs['uri'], 'https://example.com');
    });

    test('error uses toString', () {
      final json = _makeRecord(error: Exception('foo')).toExportJson();

      expect(json['error'], 'Exception: foo');
    });
  });
}
