import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/models/features.dart';
import 'package:soliplex_frontend/core/models/logo_config.dart';
import 'package:soliplex_frontend/core/models/soliplex_config.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';

void main() {
  group('shellConfigProvider', () {
    test('throws when not overridden', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Riverpod 3.0 wraps provider errors, so check the error message
      expect(
        () => container.read(shellConfigProvider),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('shellConfigProvider must be overridden'),
          ),
        ),
      );
    });

    test('provides config when overridden via ProviderScope', () {
      const customConfig = SoliplexConfig(
        logo: LogoConfig.soliplex,
        appName: 'TestApp',
        defaultBackendUrl: 'https://test.example.com',
      );

      final container = ProviderContainer(
        overrides: [shellConfigProvider.overrideWithValue(customConfig)],
      );
      addTearDown(container.dispose);

      final config = container.read(shellConfigProvider);

      expect(config.appName, equals('TestApp'));
      expect(config.defaultBackendUrl, equals('https://test.example.com'));
    });
  });

  group('featuresProvider', () {
    test('provides features from shell config', () {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(
            const SoliplexConfig(
              logo: LogoConfig.soliplex,
              features: Features(enableHttpInspector: false),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final features = container.read(featuresProvider);

      expect(features.enableHttpInspector, isFalse);
      expect(features.enableQuizzes, isTrue);
    });
  });
}
