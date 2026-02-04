import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:test/test.dart';

void main() {
  group('ConsoleSink', () {
    test('can be created with default enabled state', () {
      final sink = ConsoleSink();
      expect(sink.enabled, isTrue);
    });

    test('can be created disabled', () {
      final sink = ConsoleSink(enabled: false);
      expect(sink.enabled, isFalse);
    });

    test('write does nothing when disabled', () {
      final sink = ConsoleSink(enabled: false);
      final record = LogRecord(
        level: LogLevel.info,
        message: 'Test',
        timestamp: DateTime.now(),
        loggerName: 'Test',
      );

      // Should not throw
      sink.write(record);
    });

    test('flush completes immediately', () async {
      final sink = ConsoleSink();
      await expectLater(sink.flush(), completes);
    });

    test('close disables the sink', () async {
      final sink = ConsoleSink();
      expect(sink.enabled, isTrue);

      await sink.close();
      expect(sink.enabled, isFalse);
    });
  });
}
