import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_frontend/core/logging/logging_provider.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    LogManager.instance.reset();
  });

  tearDown(LogManager.instance.reset);

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        preloadedPrefsProvider.overrideWithValue(prefs),
      ],
    );
  }

  group('backend toggle flow', () {
    test('toggling off keeps backend sink null', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      // Initialize the controller.
      container.read(logConfigControllerProvider);

      // Backend is off by default.
      await container.read(backendLogSinkProvider.future);
      final sink = container.read(backendLogSinkProvider).value;
      expect(sink, isNull);

      // Explicitly disable — should remain null.
      await container
          .read(logConfigProvider.notifier)
          .setBackendLoggingEnabled(enabled: false);
      await container.read(backendLogSinkProvider.future);
      final sinkAfter = container.read(backendLogSinkProvider).value;
      expect(sinkAfter, isNull);
    });

    test('config persists across notifier rebuilds', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      // Enable backend logging.
      await container
          .read(logConfigProvider.notifier)
          .setBackendLoggingEnabled(enabled: true);

      // Verify persistence.
      expect(prefs.getBool('backend_logging'), isTrue);

      // Simulate rebuild by reading config again — should still be enabled.
      final config = container.read(logConfigProvider);
      expect(config.backendLoggingEnabled, isTrue);

      // Disable.
      await container
          .read(logConfigProvider.notifier)
          .setBackendLoggingEnabled(enabled: false);
      expect(prefs.getBool('backend_logging'), isFalse);

      final configAfter = container.read(logConfigProvider);
      expect(configAfter.backendLoggingEnabled, isFalse);
    });
  });
}
