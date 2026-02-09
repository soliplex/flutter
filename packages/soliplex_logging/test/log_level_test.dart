import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:test/test.dart';

void main() {
  group('LogLevel', () {
    test('has correct numeric values', () {
      expect(LogLevel.trace.value, 0);
      expect(LogLevel.debug.value, 100);
      expect(LogLevel.info.value, 200);
      expect(LogLevel.warning.value, 300);
      expect(LogLevel.error.value, 400);
      expect(LogLevel.fatal.value, 500);
    });

    test('has correct labels', () {
      expect(LogLevel.trace.label, 'TRACE');
      expect(LogLevel.debug.label, 'DEBUG');
      expect(LogLevel.info.label, 'INFO');
      expect(LogLevel.warning.label, 'WARNING');
      expect(LogLevel.error.label, 'ERROR');
      expect(LogLevel.fatal.label, 'FATAL');
    });

    test('supports >= comparison', () {
      expect(LogLevel.info >= LogLevel.debug, isTrue);
      expect(LogLevel.info >= LogLevel.info, isTrue);
      expect(LogLevel.debug >= LogLevel.info, isFalse);
    });

    test('supports < comparison', () {
      expect(LogLevel.debug < LogLevel.info, isTrue);
      expect(LogLevel.info < LogLevel.info, isFalse);
      expect(LogLevel.info < LogLevel.debug, isFalse);
    });

    test('implements Comparable', () {
      final levels = [
        LogLevel.error,
        LogLevel.trace,
        LogLevel.info,
        LogLevel.debug,
      ]..sort();

      expect(levels, [
        LogLevel.trace,
        LogLevel.debug,
        LogLevel.info,
        LogLevel.error,
      ]);
    });
  });
}
