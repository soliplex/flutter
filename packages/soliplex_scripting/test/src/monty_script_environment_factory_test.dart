import 'package:soliplex_agent/soliplex_agent.dart'
    show FakeAgentApi, HostApi, ScriptEnvironment;
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _StubHostApi implements HostApi {
  @override
  int registerDataFrame(Map<String, List<Object?>> columns) => 1;

  @override
  Map<String, List<Object?>>? getDataFrame(int handle) => null;

  @override
  int registerChart(Map<String, Object?> chartConfig) => 1;

  @override
  bool updateChart(int chartId, Map<String, Object?> chartConfig) => false;

  @override
  Future<Object?> invoke(String name, Map<String, Object?> args) async => null;
}

void main() {
  group('createMontyScriptEnvironmentFactory', () {
    test('returns a ScriptEnvironmentFactory', () async {
      final factory = createMontyScriptEnvironmentFactory(
        hostApi: _StubHostApi(),
      );
      final env = await factory();
      addTearDown(env.dispose);

      expect(env, isA<ScriptEnvironment>());
    });

    test('each call creates a fresh environment', () async {
      final factory = createMontyScriptEnvironmentFactory(
        hostApi: _StubHostApi(),
      );

      final env1 = await factory();
      final env2 = await factory();

      expect(identical(env1, env2), isFalse);

      env1.dispose();
      env2.dispose();
    });

    test('environment exposes execute_python tool', () async {
      final factory = createMontyScriptEnvironmentFactory(
        hostApi: _StubHostApi(),
      );

      final env = await factory();
      addTearDown(env.dispose);

      expect(env.tools, hasLength(1));
      expect(
        env.tools.first.definition.name,
        equals(PythonExecutorTool.toolName),
      );
    });

    test('optional agentApi is accepted', () async {
      final factory = createMontyScriptEnvironmentFactory(
        hostApi: _StubHostApi(),
        agentApi: FakeAgentApi(),
      );

      final env = await factory();
      addTearDown(env.dispose);

      expect(env, isA<MontyScriptEnvironment>());
    });

    test('optional limits override defaults', () async {
      final factory = createMontyScriptEnvironmentFactory(
        hostApi: _StubHostApi(),
        limits: MontyLimitsDefaults.tool,
      );

      final env = await factory();
      addTearDown(env.dispose);

      expect(env, isA<MontyScriptEnvironment>());
    });
  });
}
