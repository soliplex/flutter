import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:test/test.dart';

/// A test sink that records all written logs.
class TestSink implements LogSink {
  final List<LogRecord> records = [];

  @override
  void write(LogRecord record) {
    records.add(record);
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}

void main() {
  late TestSink sink;

  setUp(() {
    LogManager.instance
      ..reset()
      ..addSink(sink = TestSink());
  });

  tearDown(LogManager.instance.reset);

  group('Logger', () {
    test('logs at trace level', () {
      LogManager.instance.minimumLevel = LogLevel.trace;
      final logger = LogManager.instance.getLogger('Test')
        ..trace('Trace message');

      expect(sink.records, hasLength(1));
      expect(sink.records.first.level, LogLevel.trace);
      expect(sink.records.first.message, 'Trace message');
      expect(logger.name, 'Test'); // Use logger to avoid unused warning.
    });

    test('logs at debug level', () {
      LogManager.instance.minimumLevel = LogLevel.debug;
      LogManager.instance.getLogger('Test').debug('Debug message');

      expect(sink.records, hasLength(1));
      expect(sink.records.first.level, LogLevel.debug);
    });

    test('logs at info level', () {
      LogManager.instance.getLogger('Test').info('Info message');

      expect(sink.records, hasLength(1));
      expect(sink.records.first.level, LogLevel.info);
    });

    test('logs at warning level', () {
      LogManager.instance.getLogger('Test').warning('Warning message');

      expect(sink.records, hasLength(1));
      expect(sink.records.first.level, LogLevel.warning);
    });

    test('logs at error level', () {
      LogManager.instance.getLogger('Test').error('Error message');

      expect(sink.records, hasLength(1));
      expect(sink.records.first.level, LogLevel.error);
    });

    test('logs at fatal level', () {
      LogManager.instance.getLogger('Test').fatal('Fatal message');

      expect(sink.records, hasLength(1));
      expect(sink.records.first.level, LogLevel.fatal);
    });

    test('filters logs below minimum level', () {
      LogManager.instance.minimumLevel = LogLevel.warning;
      LogManager.instance.getLogger('Test')
        ..trace('Should not appear')
        ..debug('Should not appear')
        ..info('Should not appear')
        ..warning('Should appear')
        ..error('Should appear');

      expect(sink.records, hasLength(2));
      expect(sink.records[0].level, LogLevel.warning);
      expect(sink.records[1].level, LogLevel.error);
    });

    test('passes error and stackTrace to record', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;
      LogManager.instance
          .getLogger('Test')
          .error('Failed', error: error, stackTrace: stackTrace);

      expect(sink.records.first.error, error);
      expect(sink.records.first.stackTrace, stackTrace);
    });

    test('passes span fields to record', () {
      LogManager.instance.getLogger('Test').info(
            'Request',
            spanId: 'span-123',
            traceId: 'trace-456',
          );

      expect(sink.records.first.spanId, 'span-123');
      expect(sink.records.first.traceId, 'trace-456');
    });

    test('passes attributes to record', () {
      final attrs = {'user_id': 'u-1', 'view_name': 'settings'};
      LogManager.instance.getLogger('Test').info(
            'Navigated',
            attributes: attrs,
          );

      expect(sink.records.first.attributes, attrs);
    });

    test('attributes are defensively copied from caller', () {
      final attrs = <String, Object>{'key': 'original'};
      LogManager.instance.getLogger('Test').info(
            'Test',
            attributes: attrs,
          );

      // Mutate the caller's map after logging.
      attrs['key'] = 'mutated';
      attrs['new_key'] = 'added';

      // The logged record should retain the original values.
      expect(sink.records.first.attributes['key'], 'original');
      expect(sink.records.first.attributes.containsKey('new_key'), false);
    });

    test('attributes default to empty when not provided', () {
      LogManager.instance.getLogger('Test').info('No attrs');

      expect(sink.records.first.attributes, isEmpty);
    });

    test('sets correct logger name on records', () {
      LogManager.instance.getLogger('MyLogger').info('Test');

      expect(sink.records.first.loggerName, 'MyLogger');
    });

    test('sets timestamp on records', () {
      final before = DateTime.now();
      LogManager.instance.getLogger('Test').info('Test');
      final after = DateTime.now();

      expect(
        sink.records.first.timestamp.isAfter(before) ||
            sink.records.first.timestamp.isAtSameMomentAs(before),
        isTrue,
      );
      expect(
        sink.records.first.timestamp.isBefore(after) ||
            sink.records.first.timestamp.isAtSameMomentAs(after),
        isTrue,
      );
    });
  });
}
