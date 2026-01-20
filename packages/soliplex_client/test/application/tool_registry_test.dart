import 'dart:convert';

import 'package:soliplex_client/soliplex_client.dart';
import 'package:test/test.dart';

/// Test tool definition for registry tests.
const _testTool = Tool(
  name: 'test_tool',
  description: 'A test tool',
  parameters: {'type': 'object', 'properties': <String, dynamic>{}},
);

/// Another test tool for multi-tool tests.
const _adderTool = Tool(
  name: 'adder',
  description: 'Adds numbers',
  parameters: {
    'type': 'object',
    'properties': {
      'a': {'type': 'number'},
      'b': {'type': 'number'},
    },
  },
);

void main() {
  group('ToolRegistry', () {
    test('empty registry has no executors', () {
      const registry = ToolRegistry();
      expect(registry.hasExecutor('any_tool'), isFalse);
    });

    test('empty registry returns empty definitions', () {
      const registry = ToolRegistry();
      expect(registry.definitions, isEmpty);
    });

    test('register returns new registry with tool', () {
      const registry = ToolRegistry();
      final newRegistry = registry.register(_testTool, (_) => 'result');

      // Original unchanged (immutability)
      expect(registry.hasExecutor('test_tool'), isFalse);
      expect(registry.definitions, isEmpty);

      // New registry has tool
      expect(newRegistry.hasExecutor('test_tool'), isTrue);
      expect(newRegistry.definitions, hasLength(1));
    });

    test('hasExecutor returns true for registered tool', () {
      final registry = const ToolRegistry().register(_testTool, (_) => 'ok');
      expect(registry.hasExecutor('test_tool'), isTrue);
    });

    test('hasExecutor returns false for unregistered tool', () {
      final registry = const ToolRegistry().register(_testTool, (_) => 'ok');
      expect(registry.hasExecutor('other_tool'), isFalse);
    });

    test('execute calls registered executor', () async {
      final registry = const ToolRegistry().register(
        _adderTool,
        (call) => 'executed: ${call.arguments}',
      );

      const call = ToolCallInfo(id: '1', name: 'adder', arguments: '{"a":1}');
      final result = await registry.execute(call);

      expect(result, equals('executed: {"a":1}'));
    });

    test('execute throws StateError for unregistered tool', () async {
      const registry = ToolRegistry();
      const call = ToolCallInfo(id: '1', name: 'unknown');

      await expectLater(
        registry.execute(call),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('No executor registered for tool: unknown'),
          ),
        ),
      );
    });

    group('definitions', () {
      test('returns tool definitions for all registered tools', () {
        final registry = const ToolRegistry()
            .register(_testTool, (_) => 'a')
            .register(_adderTool, (_) => 'b');

        final definitions = registry.definitions;

        expect(definitions, hasLength(2));
        expect(
          definitions.map((t) => t.name),
          containsAll(['test_tool', 'adder']),
        );
      });

      test('returns tool with correct properties', () {
        final registry = const ToolRegistry().register(_adderTool, (_) => '');

        final definitions = registry.definitions;

        expect(definitions, hasLength(1));
        expect(definitions.first.name, equals('adder'));
        expect(definitions.first.description, equals('Adds numbers'));
        expect(definitions.first.parameters, isA<Map<String, dynamic>>());
      });
    });
  });

  group('ClientTool', () {
    test('holds definition and executor', () {
      String executor(ToolCallInfo call) => 'result';
      final clientTool = ClientTool(definition: _testTool, executor: executor);

      expect(clientTool.definition.name, equals('test_tool'));
      expect(clientTool.executor, equals(executor));
    });
  });

  group('getSecretTool definition', () {
    test('has correct name', () {
      expect(getSecretTool.name, equals('get_secret'));
    });

    test('has description', () {
      expect(getSecretTool.description, isNotEmpty);
      expect(getSecretTool.description.toLowerCase(), contains('date'));
    });

    test('has parameters schema', () {
      expect(getSecretTool.parameters, isA<Map<String, dynamic>>());
      final params = getSecretTool.parameters as Map<String, dynamic>;
      expect(params['type'], equals('object'));
    });
  });

  group('getSecretExecutor', () {
    test('returns valid JSON with UTC date', () {
      const call = ToolCallInfo(id: '1', name: 'get_secret');
      final result = getSecretExecutor(call);

      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json, contains('date'));

      final dateStr = json['date'] as String;
      // Verify date format: YYYY-MM-DD
      expect(dateStr, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));

      // Verify it matches today's UTC date
      final now = DateTime.now().toUtc();
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      final expected = '${now.year}-$month-$day';
      expect(dateStr, equals(expected));
    });
  });
}
