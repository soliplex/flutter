import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/logging/log_config.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

void main() {
  group('LogConfig', () {
    test('defaultConfig has sensible defaults', () {
      expect(LogConfig.defaultConfig.minimumLevel, LogLevel.debug);
      expect(LogConfig.defaultConfig.consoleLoggingEnabled, isTrue);
      expect(LogConfig.defaultConfig.stdoutLoggingEnabled, isTrue);
    });

    test('creates with specified values', () {
      const config = LogConfig(
        minimumLevel: LogLevel.debug,
        consoleLoggingEnabled: false,
        stdoutLoggingEnabled: false,
      );

      expect(config.minimumLevel, LogLevel.debug);
      expect(config.consoleLoggingEnabled, isFalse);
      expect(config.stdoutLoggingEnabled, isFalse);
    });

    group('copyWith', () {
      test('copies minimumLevel only', () {
        const original = LogConfig.defaultConfig;

        final copied = original.copyWith(minimumLevel: LogLevel.warning);

        expect(copied.minimumLevel, LogLevel.warning);
        expect(copied.consoleLoggingEnabled, isTrue);
        expect(copied.stdoutLoggingEnabled, isTrue);
      });

      test('copies consoleLoggingEnabled only', () {
        const original = LogConfig.defaultConfig;

        final copied = original.copyWith(consoleLoggingEnabled: false);

        expect(copied.minimumLevel, LogLevel.debug);
        expect(copied.consoleLoggingEnabled, isFalse);
        expect(copied.stdoutLoggingEnabled, isTrue);
      });

      test('copies stdoutLoggingEnabled only', () {
        const original = LogConfig.defaultConfig;

        final copied = original.copyWith(stdoutLoggingEnabled: false);

        expect(copied.minimumLevel, LogLevel.debug);
        expect(copied.consoleLoggingEnabled, isTrue);
        expect(copied.stdoutLoggingEnabled, isFalse);
      });

      test('copies all values', () {
        const original = LogConfig.defaultConfig;

        final copied = original.copyWith(
          minimumLevel: LogLevel.error,
          consoleLoggingEnabled: false,
          stdoutLoggingEnabled: false,
        );

        expect(copied.minimumLevel, LogLevel.error);
        expect(copied.consoleLoggingEnabled, isFalse);
        expect(copied.stdoutLoggingEnabled, isFalse);
      });

      test('preserves values when no arguments given', () {
        const original = LogConfig(
          minimumLevel: LogLevel.debug,
          consoleLoggingEnabled: false,
          stdoutLoggingEnabled: false,
        );

        final copied = original.copyWith();

        expect(copied.minimumLevel, LogLevel.debug);
        expect(copied.consoleLoggingEnabled, isFalse);
        expect(copied.stdoutLoggingEnabled, isFalse);
      });
    });

    group('equality', () {
      test('equal configs are equal', () {
        const config1 = LogConfig.defaultConfig;
        const config2 = LogConfig.defaultConfig;

        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('different minimumLevel are not equal', () {
        const config1 = LogConfig.defaultConfig;
        const config2 = LogConfig(
          minimumLevel: LogLevel.warning,
          consoleLoggingEnabled: true,
          stdoutLoggingEnabled: true,
        );

        expect(config1, isNot(equals(config2)));
      });

      test('different consoleLoggingEnabled are not equal', () {
        const config1 = LogConfig.defaultConfig;
        const config2 = LogConfig(
          minimumLevel: LogLevel.debug,
          consoleLoggingEnabled: false,
          stdoutLoggingEnabled: true,
        );

        expect(config1, isNot(equals(config2)));
      });

      test('different stdoutLoggingEnabled are not equal', () {
        const config1 = LogConfig.defaultConfig;
        const config2 = LogConfig(
          minimumLevel: LogLevel.debug,
          consoleLoggingEnabled: true,
          stdoutLoggingEnabled: false,
        );

        expect(config1, isNot(equals(config2)));
      });
    });

    test('toString returns expected format', () {
      const config = LogConfig(
        minimumLevel: LogLevel.warning,
        consoleLoggingEnabled: false,
        stdoutLoggingEnabled: true,
      );

      expect(
        config.toString(),
        'LogConfig(minimumLevel: LogLevel.warning, '
        'consoleLoggingEnabled: false, '
        'stdoutLoggingEnabled: true)',
      );
    });
  });
}
