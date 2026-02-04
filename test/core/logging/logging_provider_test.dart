import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_frontend/core/logging/log_config.dart';
import 'package:soliplex_frontend/core/logging/logging_provider.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

void main() {
  setUp(() {
    // Reset SharedPreferences mock before each test.
    SharedPreferences.setMockInitialValues({});
    // Reset LogManager.
    LogManager.instance.reset();
  });

  tearDown(LogManager.instance.reset);

  group('LogConfigNotifier', () {
    test('loads default config when no preferences exist', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final config = await container.read(logConfigProvider.future);

      expect(config.minimumLevel, LogConfig.defaultConfig.minimumLevel);
      expect(
        config.consoleLoggingEnabled,
        LogConfig.defaultConfig.consoleLoggingEnabled,
      );
    });

    test('loads saved log level from preferences', () async {
      SharedPreferences.setMockInitialValues({
        'log_level': LogLevel.debug.index,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final config = await container.read(logConfigProvider.future);

      expect(config.minimumLevel, LogLevel.debug);
    });

    test('loads saved console logging state from preferences', () async {
      SharedPreferences.setMockInitialValues({
        'console_logging': false,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final config = await container.read(logConfigProvider.future);

      expect(config.consoleLoggingEnabled, isFalse);
    });

    test('setMinimumLevel updates state and persists', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(logConfigProvider.notifier);
      await container.read(logConfigProvider.future);

      await notifier.setMinimumLevel(LogLevel.error);

      final config = await container.read(logConfigProvider.future);
      expect(config.minimumLevel, LogLevel.error);

      // Verify persistence.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('log_level'), LogLevel.error.index);
    });

    test('setConsoleLoggingEnabled updates state and persists', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(logConfigProvider.notifier);
      await container.read(logConfigProvider.future);

      await notifier.setConsoleLoggingEnabled(enabled: false);

      final config = await container.read(logConfigProvider.future);
      expect(config.consoleLoggingEnabled, isFalse);

      // Verify persistence.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('console_logging'), isFalse);
    });
  });

  group('consoleSinkProvider', () {
    test('uses default config while loading', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read the sink provider immediately (before async config loads).
      final sink = container.read(consoleSinkProvider);

      // Should still return a sink because default is enabled.
      expect(sink, isNotNull);
      expect(LogManager.instance.sinks, contains(sink));
    });

    test('applies minimum level to LogManager', () async {
      SharedPreferences.setMockInitialValues({
        'log_level': LogLevel.warning.index,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read and wait for config.
      await container.read(logConfigProvider.future);
      container.read(consoleSinkProvider);

      expect(LogManager.instance.minimumLevel, LogLevel.warning);
    });

    test('returns null when console logging disabled', () async {
      SharedPreferences.setMockInitialValues({
        'console_logging': false,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Wait for config to load.
      await container.read(logConfigProvider.future);
      final sink = container.read(consoleSinkProvider);

      expect(sink, isNull);
    });

    test('removes sink on dispose', () async {
      final container = ProviderContainer();

      // Read and wait for config.
      await container.read(logConfigProvider.future);
      final sink = container.read(consoleSinkProvider);
      expect(LogManager.instance.sinks, contains(sink));

      container.dispose();

      // After dispose, sink should be removed.
      expect(LogManager.instance.sinks, isEmpty);
    });
  });
}
