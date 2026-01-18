import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/extension/soliplex_registry.dart';
import 'package:soliplex_frontend/core/models/features.dart';
import 'package:soliplex_frontend/core/models/soliplex_config.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';

void main() {
  group('shellConfigProvider', () {
    test('provides default SoliplexConfig before initialization', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final config = container.read(shellConfigProvider);

      expect(config.appName, equals('Soliplex'));
    });

    test('provides custom config after initialization', () {
      initializeShellConfig(
        config: const SoliplexConfig(
          appName: 'TestApp',
          defaultBackendUrl: 'https://test.example.com',
        ),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final config = container.read(shellConfigProvider);

      expect(config.appName, equals('TestApp'));
      expect(config.defaultBackendUrl, equals('https://test.example.com'));

      // Reset for other tests
      initializeShellConfig();
    });
  });

  group('registryProvider', () {
    test('provides EmptyRegistry by default', () {
      initializeShellConfig();

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final registry = container.read(registryProvider);

      expect(registry, isA<EmptyRegistry>());
      expect(registry.panels, isEmpty);
      expect(registry.commands, isEmpty);
      expect(registry.routes, isEmpty);
    });

    test('provides custom registry after initialization', () {
      final customRegistry = _TestRegistry();

      initializeShellConfig(registry: customRegistry);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final registry = container.read(registryProvider);

      expect(registry, equals(customRegistry));
      expect(registry.panels, hasLength(1));

      // Reset for other tests
      initializeShellConfig();
    });
  });

  group('featuresProvider', () {
    test('provides features from shell config', () {
      initializeShellConfig(
        config: const SoliplexConfig(
          features: Features(enableHttpInspector: false),
        ),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final features = container.read(featuresProvider);

      expect(features.enableHttpInspector, isFalse);
      expect(features.enableQuizzes, isTrue);

      // Reset for other tests
      initializeShellConfig();
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
