import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_frontend/core/logging/log_config.dart';
import 'package:soliplex_frontend/core/logging/logging_provider.dart';
import 'package:soliplex_frontend/core/providers/connectivity_provider.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    // Reset SharedPreferences mock before each test.
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    // Reset LogManager.
    LogManager.instance.reset();
  });

  tearDown(LogManager.instance.reset);

  /// Creates a container with pre-loaded prefs for synchronous config loading.
  ProviderContainer createContainer(SharedPreferences preloadedPrefs) {
    return ProviderContainer(
      overrides: [
        preloadedPrefsProvider.overrideWithValue(preloadedPrefs),
        connectivityProvider.overrideWith(
          (ref) => Stream.value([ConnectivityResult.wifi]),
        ),
      ],
    );
  }

  group('LogConfigNotifier', () {
    test('loads default config when no preferences exist', () {
      final container = createContainer(prefs);
      addTearDown(container.dispose);

      final config = container.read(logConfigProvider);

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
      prefs = await SharedPreferences.getInstance();

      final container = createContainer(prefs);
      addTearDown(container.dispose);

      final config = container.read(logConfigProvider);

      expect(config.minimumLevel, LogLevel.debug);
    });

    test('loads saved console logging state from preferences', () async {
      SharedPreferences.setMockInitialValues({
        'console_logging': false,
      });
      prefs = await SharedPreferences.getInstance();

      final container = createContainer(prefs);
      addTearDown(container.dispose);

      final config = container.read(logConfigProvider);

      expect(config.consoleLoggingEnabled, isFalse);
    });

    test('setMinimumLevel updates state and persists', () async {
      final container = createContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(logConfigProvider.notifier);

      await notifier.setMinimumLevel(LogLevel.error);

      final config = container.read(logConfigProvider);
      expect(config.minimumLevel, LogLevel.error);

      // Verify persistence.
      expect(prefs.getInt('log_level'), LogLevel.error.index);
    });

    test('setConsoleLoggingEnabled updates state and persists', () async {
      final container = createContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(logConfigProvider.notifier);

      await notifier.setConsoleLoggingEnabled(enabled: false);

      final config = container.read(logConfigProvider);
      expect(config.consoleLoggingEnabled, isFalse);

      // Verify persistence.
      expect(prefs.getBool('console_logging'), isFalse);
    });

    test('loads saved backend logging state from preferences', () async {
      SharedPreferences.setMockInitialValues({
        'backend_logging': true,
        'backend_endpoint': '/custom/logs',
      });
      prefs = await SharedPreferences.getInstance();

      final container = createContainer(prefs);
      addTearDown(container.dispose);

      final config = container.read(logConfigProvider);

      expect(config.backendLoggingEnabled, isTrue);
      expect(config.backendEndpoint, '/custom/logs');
    });

    test('setBackendLoggingEnabled updates state and persists', () async {
      final container = createContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(logConfigProvider.notifier);

      await notifier.setBackendLoggingEnabled(enabled: true);

      final config = container.read(logConfigProvider);
      expect(config.backendLoggingEnabled, isTrue);

      // Verify persistence.
      expect(prefs.getBool('backend_logging'), isTrue);
    });

    test('setBackendEndpoint updates state and persists', () async {
      final container = createContainer(prefs);
      addTearDown(container.dispose);

      final notifier = container.read(logConfigProvider.notifier);

      await notifier.setBackendEndpoint('/v2/logs');

      final config = container.read(logConfigProvider);
      expect(config.backendEndpoint, '/v2/logs');

      // Verify persistence.
      expect(prefs.getString('backend_endpoint'), '/v2/logs');
    });

    test('throws when prefs provider not overridden', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Riverpod wraps the StateError in a ProviderException.
      expect(
        () => container.read(logConfigProvider),
        throwsA(anything),
      );
    });
  });

  group('consoleSinkProvider', () {
    test('creates sink and registers with LogManager', () {
      final container = createContainer(prefs);
      addTearDown(container.dispose);

      final sink = container.read(consoleSinkProvider);

      expect(sink, isA<ConsoleSink>());
      expect(LogManager.instance.sinks, contains(sink));
    });

    test('sink starts disabled', () {
      final container = createContainer(prefs);
      addTearDown(container.dispose);

      final sink = container.read(consoleSinkProvider);

      // Sink starts disabled until controller enables it.
      expect(sink.enabled, isFalse);
    });

    test('removes sink on dispose', () {
      final container = createContainer(prefs);

      final sink = container.read(consoleSinkProvider);
      expect(LogManager.instance.sinks, contains(sink));

      container.dispose();

      // After dispose, sink should be removed.
      expect(LogManager.instance.sinks, isEmpty);
    });
  });

  group('stdoutSinkProvider', () {
    test('returns null on non-desktop platforms', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final container = createContainer(prefs);
      addTearDown(container.dispose);

      final sink = container.read(stdoutSinkProvider);
      expect(sink, isNull);
    });

    test('returns sink on desktop platforms', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final container = createContainer(prefs);
      addTearDown(container.dispose);

      final sink = container.read(stdoutSinkProvider);
      expect(sink, isA<StdoutSink>());
    });
  });

  group('logConfigControllerProvider', () {
    test('enables sinks immediately when prefs are pre-loaded', () {
      final container = createContainer(prefs);
      addTearDown(container.dispose);

      // Read controller to start listening.
      container.read(logConfigControllerProvider);

      // Sink should be enabled immediately (no async wait needed).
      final sink = container.read(consoleSinkProvider);
      expect(sink.enabled, isTrue);
    });

    test('applies minimum level to LogManager', () async {
      SharedPreferences.setMockInitialValues({
        'log_level': LogLevel.warning.index,
      });
      prefs = await SharedPreferences.getInstance();

      final container = createContainer(prefs);
      addTearDown(container.dispose);

      // Read controller to start listening.
      container.read(logConfigControllerProvider);

      expect(LogManager.instance.minimumLevel, LogLevel.warning);
    });

    test('disables sink when config has console logging disabled', () async {
      SharedPreferences.setMockInitialValues({
        'console_logging': false,
      });
      prefs = await SharedPreferences.getInstance();

      final container = createContainer(prefs);
      addTearDown(container.dispose);

      // Read controller to start listening.
      container.read(logConfigControllerProvider);

      final sink = container.read(consoleSinkProvider);
      expect(sink.enabled, isFalse);
    });

    test('updates sink enabled state when config changes', () async {
      final container = createContainer(prefs);
      addTearDown(container.dispose);

      // Read controller to start listening.
      container.read(logConfigControllerProvider);

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
