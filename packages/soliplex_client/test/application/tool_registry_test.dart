import 'package:ag_ui/ag_ui.dart';
import 'package:soliplex_client/src/application/tool_registry.dart';
import 'package:soliplex_client/src/domain/chat_message.dart';
import 'package:test/test.dart';

/// Inline test tool — no demo tool shipped in the package.
ClientTool _testTool({
  String name = 'test_tool',
  String description = 'A test tool',
  Future<String> Function(ToolCallInfo)? executor,
}) {
  return ClientTool(
    definition: Tool(name: name, description: description),
    executor: executor ?? (_) async => 'test result',
  );
}

void main() {
  group('ToolRegistry', () {
    test('register adds tool to registry', () {
      const registry = ToolRegistry();
      final updated = registry.register(_testTool());

      expect(updated.contains('test_tool'), isTrue);
      expect(updated.length, 1);
    });

    test('register returns new registry (immutable)', () {
      const registry = ToolRegistry();
      final updated = registry.register(_testTool());

      expect(registry.isEmpty, isTrue);
      expect(updated.isEmpty, isFalse);
    });

    test('lookup returns tool by name', () {
      final registry = const ToolRegistry().register(_testTool());

      final tool = registry.lookup('test_tool');

      expect(tool.definition.name, 'test_tool');
    });

    test('lookup throws StateError for unknown tool', () {
      const registry = ToolRegistry();

      expect(
        () => registry.lookup('nonexistent'),
        throwsA(isA<StateError>()),
      );
    });

    test('execute runs the tool executor', () async {
      final registry = const ToolRegistry().register(
        _testTool(executor: (_) async => 'hello from tool'),
      );
      const toolCall = ToolCallInfo(id: 'tc-1', name: 'test_tool');

      final result = await registry.execute(toolCall);

      expect(result, 'hello from tool');
    });

    test('execute with failing executor propagates exception', () async {
      final registry = const ToolRegistry().register(
        _testTool(executor: (_) async => throw Exception('boom')),
      );
      const toolCall = ToolCallInfo(id: 'tc-1', name: 'test_tool');

      expect(
        () => registry.execute(toolCall),
        throwsA(isA<Exception>()),
      );
    });

    test('toolDefinitions returns ag_ui Tool list', () {
      final registry = const ToolRegistry()
          .register(_testTool(name: 'tool_a', description: 'A'))
          .register(_testTool(name: 'tool_b', description: 'B'));

      final definitions = registry.toolDefinitions;

      expect(definitions, hasLength(2));
      expect(definitions.map((t) => t.name), containsAll(['tool_a', 'tool_b']));
    });
  });
}
