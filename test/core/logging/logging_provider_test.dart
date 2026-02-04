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
    test('creates sink and registers with LogManager', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sink = container.read(consoleSinkProvider);

      expect(sink, isA<ConsoleSink>());
      expect(LogManager.instance.sinks, contains(sink));
    });

    test('sink starts disabled', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sink = container.read(consoleSinkProvider);

      // Sink starts disabled until controller enables it.
      expect(sink.enabled, isFalse);
    });

    test('removes sink on dispose', () {
      final container = ProviderContainer();

      final sink = container.read(consoleSinkProvider);
      expect(LogManager.instance.sinks, contains(sink));

      container.dispose();

      // After dispose, sink should be removed.
      expect(LogManager.instance.sinks, isEmpty);
    });
  });

  group('logConfigControllerProvider', () {
    test('enables sinks when config loads with defaults', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read controller to start listening.
      container.read(logConfigControllerProvider);

      // Wait for config to load.
      await container.read(logConfigProvider.future);

      // Sink should now be enabled (default config enables console logging).
      final sink = container.read(consoleSinkProvider);
      expect(sink.enabled, isTrue);
    });

    test('applies minimum level to LogManager', () async {
      SharedPreferences.setMockInitialValues({
        'log_level': LogLevel.warning.index,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read controller to start listening.
      container.read(logConfigControllerProvider);

      // Wait for config to load.
      await container.read(logConfigProvider.future);

      expect(LogManager.instance.minimumLevel, LogLevel.warning);
    });

    test('disables sink when config has console logging disabled', () async {
      SharedPreferences.setMockInitialValues({
        'console_logging': false,
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read controller to start listening.
      container.read(logConfigControllerProvider);

      // Wait for config to load.
      await container.read(logConfigProvider.future);

      final sink = container.read(consoleSinkProvider);
      expect(sink.enabled, isFalse);
    });

    test('updates sink enabled state when config changes', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read controller to start listening.
      container.read(logConfigControllerProvider);

      // Wait for config to load.
      await container.read(logConfigProvider.future);

      final sink = container.read(consoleSinkProvider);
      expect(sink.enabled, isTrue);

      // Disable console logging.
      final notifier = container.read(logConfigProvider.notifier);
      await notifier.setConsoleLoggingEnabled(enabled: false);

      // Sink should now be disabled.
      expect(sink.enabled, isFalse);

      // Re-enable.
      await notifier.setConsoleLoggingEnabled(enabled: true);
      expect(sink.enabled, isTrue);
    });
  });
}
