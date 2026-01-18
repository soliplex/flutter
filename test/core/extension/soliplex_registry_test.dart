import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/extension/soliplex_registry.dart';

void main() {
  group('EmptyRegistry', () {
    test('panels returns empty list', () {
      const registry = EmptyRegistry();

      expect(registry.panels, isEmpty);
    });

    test('commands returns empty list', () {
      const registry = EmptyRegistry();

      expect(registry.commands, isEmpty);
    });

    test('routes returns empty list', () {
      const registry = EmptyRegistry();

      expect(registry.routes, isEmpty);
    });
  });

  group('PanelDefinition', () {
    test('stores all properties', () {
      final definition = PanelDefinition(
        id: 'test-panel',
        label: 'Test Panel',
        icon: Icons.star,
        builder: (context) => const SizedBox(),
      );

      expect(definition.id, equals('test-panel'));
      expect(definition.label, equals('Test Panel'));
      expect(definition.icon, equals(Icons.star));
      expect(definition.builder, isNotNull);
    });
  });

  group('CommandDefinition', () {
    test('stores all properties', () {
      Future<String?> handler(String args) async => 'response';

      final definition = CommandDefinition(
        name: 'test',
        description: 'A test command',
        handler: handler,
      );

      expect(definition.name, equals('test'));
      expect(definition.description, equals('A test command'));
      expect(definition.handler, equals(handler));
    });

    test('handler can be invoked', () async {
      final definition = CommandDefinition(
        name: 'echo',
        description: 'Echoes input',
        handler: (args) async => 'Echo: $args',
      );

      final result = await definition.handler('hello');

      expect(result, equals('Echo: hello'));
    });
  });

  group('RouteDefinition', () {
    test('stores required properties', () {
      final definition = RouteDefinition(
        path: '/custom',
        builder: (context, params) => const SizedBox(),
      );

      expect(definition.path, equals('/custom'));
      expect(definition.builder, isNotNull);
      expect(definition.redirect, isNull);
    });

    test('stores optional redirect', () {
      final definition = RouteDefinition(
        path: '/custom',
        builder: (context, params) => const SizedBox(),
        redirect: (context) => '/other',
      );

      expect(definition.redirect, isNotNull);
    });
  });

  group('Custom registry implementation', () {
    test('can implement SoliplexRegistry', () {
      final registry = _TestRegistry();

      expect(registry.panels, hasLength(1));
      expect(registry.commands, hasLength(1));
      expect(registry.routes, hasLength(1));
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
  List<CommandDefinition> get commands => [
        CommandDefinition(
          name: 'test',
          description: 'Test command',
          handler: (_) async => null,
        ),
      ];

  @override
  List<RouteDefinition> get routes => [
        RouteDefinition(
          path: '/test',
          builder: (_, __) => const SizedBox(),
        ),
      ];
}
