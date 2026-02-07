import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:test/test.dart';

/// A test sink that records all written logs.
class _TestSink implements LogSink {
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
  late _TestSink sink;

  setUp(() {
    LogManager.instance
      ..reset()
      ..addSink(sink = _TestSink());
  });

  tearDown(LogManager.instance.reset);

  group('LogManager with sanitizer', () {
    test('sanitizes records before dispatching to sinks', () {
      LogManager.instance.sanitizer = LogSanitizer();

      LogManager.instance.getLogger('Auth').info(
        'User user@example.com logged in',
        attributes: const {'password': 'secret123'},
      );

      expect(sink.records, hasLength(1));
      final record = sink.records.first;
      expect(record.message, contains('[REDACTED]'));
      expect(record.message, isNot(contains('user@example.com')));
      expect(record.attributes['password'], '[REDACTED]');
    });

    test('all sinks receive sanitized data', () {
      LogManager.instance.sanitizer = LogSanitizer();
      final sink2 = _TestSink();
      LogManager.instance.addSink(sink2);

      LogManager.instance.getLogger('Test').info(
        'Email: admin@test.com',
        attributes: const {'token': 'jwt-abc'},
      );

      for (final s in [sink, sink2]) {
        final record = s.records.first;
        expect(record.message, isNot(contains('admin@test.com')));
        expect(record.attributes['token'], '[REDACTED]');
      }
    });
  });

  group('LogManager without sanitizer', () {
    test('passes records unmodified when no sanitizer set', () {
      // sanitizer is null by default after reset()
      LogManager.instance.getLogger('Test').info(
        'Email: admin@test.com',
        attributes: const {'token': 'jwt-abc'},
      );

      expect(sink.records, hasLength(1));
      final record = sink.records.first;
      expect(record.message, contains('admin@test.com'));
      expect(record.attributes['token'], 'jwt-abc');
    });
  });
}
