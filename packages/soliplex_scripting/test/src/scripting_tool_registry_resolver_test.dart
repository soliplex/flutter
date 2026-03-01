import 'package:soliplex_agent/soliplex_agent.dart' show HostApi;
import 'package:soliplex_client/soliplex_client.dart'
    show ClientTool, Tool, ToolCallInfo, ToolRegistry;
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

const ThreadKey _key = (serverId: 's', roomId: 'r', threadId: 't');

/// Minimal HostApi stub — not under test here.
class _StubHostApi implements HostApi {
  @override
  int registerDataFrame(Map<String, List<Object?>> columns) => 1;

  @override
  Map<String, List<Object?>>? getDataFrame(int handle) => null;

  @override
  int registerChart(Map<String, Object?> chartConfig) => 1;

  @override
  Future<Object?> invoke(
    String name,
    Map<String, Object?> args,
  ) async =>
      null;
}

Future<ToolRegistry> _emptyResolver(String roomId) async {
  return const ToolRegistry();
}

void main() {
  group('ScriptingToolRegistryResolver', () {
    late MontyToolExecutor executor;

    setUp(() {
      final cache = BridgeCache(limit: 1);
      executor = MontyToolExecutor(
        threadKey: _key,
        bridgeCache: cache,
        hostWiring: HostFunctionWiring(hostApi: _StubHostApi()),
      );
    });

    test('delegates to inner then appends execute_python', () async {
      final resolver = ScriptingToolRegistryResolver(
        inner: _emptyResolver,
        executor: executor,
      );

      final registry = await resolver.call('room-1');

      expect(registry.contains(PythonExecutorTool.toolName), isTrue);
      expect(registry.length, 1);
    });

    test('preserves tools from inner resolver', () async {
      final existingTool = ClientTool(
        definition: const Tool(
          name: 'existing_tool',
          description: 'A pre-existing tool',
          parameters: <String, Object?>{},
        ),
        executor: (ToolCallInfo _) async => 'noop',
      );

      Future<ToolRegistry> inner(String roomId) async {
        return const ToolRegistry().register(existingTool);
      }

      final resolver = ScriptingToolRegistryResolver(
        inner: inner,
        executor: executor,
      );

      final registry = await resolver.call('room-1');

      expect(registry.contains('existing_tool'), isTrue);
      expect(
        registry.contains(PythonExecutorTool.toolName),
        isTrue,
      );
      expect(registry.length, 2);
    });

    test('registered tool has PythonExecutorTool.definition', () async {
      final resolver = ScriptingToolRegistryResolver(
        inner: _emptyResolver,
        executor: executor,
      );

      final registry = await resolver.call('room-1');
      final tool = registry.lookup(PythonExecutorTool.toolName);

      expect(tool.definition, PythonExecutorTool.definition);
    });

    test('executor wired to MontyToolExecutor.execute', () async {
      final resolver = ScriptingToolRegistryResolver(
        inner: _emptyResolver,
        executor: executor,
      );

      final registry = await resolver.call('room-1');
      final tool = registry.lookup(PythonExecutorTool.toolName);

      expect(tool.executor, equals(executor.execute));
    });
  });
}
