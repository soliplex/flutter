import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/extension/soliplex_registry.dart';
import 'package:soliplex_frontend/core/models/features.dart';
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
        appName: 'TestApp',
        defaultBackendUrl: 'https://test.example.com',
      );

      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(customConfig),
        ],
      );
      addTearDown(container.dispose);

      final config = container.read(shellConfigProvider);

      expect(config.appName, equals('TestApp'));
      expect(config.defaultBackendUrl, equals('https://test.example.com'));
    });
  });

  group('registryProvider', () {
    test('provides EmptyRegistry by default', () {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(const SoliplexConfig()),
        ],
      );
      addTearDown(container.dispose);

      final registry = container.read(registryProvider);

      expect(registry, isA<EmptyRegistry>());
      expect(registry.panels, isEmpty);
      expect(registry.commands, isEmpty);
      expect(registry.routes, isEmpty);
    });

    test('provides custom registry when overridden', () {
      final customRegistry = _TestRegistry();

      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(const SoliplexConfig()),
          registryProvider.overrideWithValue(customRegistry),
        ],
      );
      addTearDown(container.dispose);

      final registry = container.read(registryProvider);

      expect(registry, equals(customRegistry));
      expect(registry.panels, hasLength(1));
    });
  });

  group('featuresProvider', () {
    test('provides features from shell config', () {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(
            const SoliplexConfig(
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

class _TestRegistry implements SoliplexRegistry {
  @override
  List<PanelDefinition> get panels => [
        PanelDefinition(
          id: 'test',
          label: 'Test',
          icon: Icons.star,
          builder: (_) => const SizedBox(),
        ),
      ];

  @override
  List<CommandDefinition> get commands => [];

  @override
  List<RouteDefinition> get routes => [];
}
