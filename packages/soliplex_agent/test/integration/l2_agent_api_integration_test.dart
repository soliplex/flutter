// Integration tests use print for diagnostic output.
// ignore_for_file: avoid_print
@Tags(['integration'])
@Timeout(Duration(minutes: 3))
library;

import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:test/test.dart';

import 'helpers/helpers.dart';

/// ------------------------------------------------------------------
/// L2 Agent Primitives Integration Tests
///
/// Tests RuntimeAgentApi against a real AgentRuntime + backend.
///
/// Prerequisites:
///   1. Running Soliplex backend with `echo` and `parallel` rooms
///
/// Run:
///   SOLIPLEX_BASE_URL=http://localhost:8000 \
///   dart test test/integration/l2_agent_api_integration_test.dart \
///     -t integration
/// ------------------------------------------------------------------

void main() {
  final harness = IntegrationHarness();

  setUpAll(() async {
    await harness.setUp();
  });

  tearDownAll(harness.tearDown);

  // ===========================================================================
  // 1. spawn_agent + get_result
  // ===========================================================================
  group('spawn_agent + get_result', () {
    late AgentRuntime runtime;
    late RuntimeAgentApi agentApi;

    setUp(() {
      runtime = harness.createRuntime(loggerName: 'l2-01-spawn');
      agentApi = RuntimeAgentApi(runtime: runtime);
    });

    tearDown(() async {
      await runtime.dispose();
    });

    test('spawns agent in echo room and retrieves result', () async {
      final handle = await agentApi.spawnAgent('echo', 'Say exactly: PING');
      print('Spawned handle: $handle');
      expect(handle, isPositive);

      final result = await agentApi.getResult(
        handle,
        timeout: const Duration(seconds: 60),
      );
      print('Result: $result');
      expect(result, isNotEmpty);
      expect(result.toUpperCase(), contains('PING'));
    });
  });

  // ===========================================================================
  // 2. wait_all fan-out
  // ===========================================================================
  group('wait_all fan-out', () {
    late AgentRuntime runtime;
    late RuntimeAgentApi agentApi;

    setUp(() {
      runtime = harness.createRuntime(loggerName: 'l2-02-waitall');
      agentApi = RuntimeAgentApi(runtime: runtime);
    });

    tearDown(() async {
      await runtime.dispose();
    });

    test('spawns 3 agents and waits for all results', () async {
      final h1 = await agentApi.spawnAgent('echo', 'Say exactly: ALPHA');
      final h2 = await agentApi.spawnAgent('echo', 'Say exactly: BETA');
      final h3 = await agentApi.spawnAgent('echo', 'Say exactly: GAMMA');
      print('Handles: $h1, $h2, $h3');

      final results = await agentApi.waitAll(
        [h1, h2, h3],
        timeout: const Duration(seconds: 90),
      );
      print('Results: $results');

      expect(results, hasLength(3));
      expect(results[0].toUpperCase(), contains('ALPHA'));
      expect(results[1].toUpperCase(), contains('BETA'));
      expect(results[2].toUpperCase(), contains('GAMMA'));
    });
  });

  // ===========================================================================
  // 3. cancel_agent
  // ===========================================================================
  group('cancel_agent', () {
    late AgentRuntime runtime;
    late RuntimeAgentApi agentApi;

    setUp(() {
      runtime = harness.createRuntime(loggerName: 'l2-03-cancel');
      agentApi = RuntimeAgentApi(runtime: runtime);
    });

    tearDown(() async {
      await runtime.dispose();
    });

    test('cancels a running agent', () async {
      final handle = await agentApi.spawnAgent(
        'echo',
        'Write a very long essay about the history of computing.',
      );
      print('Spawned handle: $handle');

      final cancelled = await agentApi.cancelAgent(handle);
      expect(cancelled, isTrue);
      print('Cancelled: $cancelled');

      // getResult should throw because the agent was cancelled.
      expect(
        () => agentApi.getResult(
          handle,
          timeout: const Duration(seconds: 30),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ===========================================================================
  // 4. Unknown handle errors
  // ===========================================================================
  group('error handling', () {
    late AgentRuntime runtime;
    late RuntimeAgentApi agentApi;

    setUp(() {
      runtime = harness.createRuntime(loggerName: 'l2-04-errors');
      agentApi = RuntimeAgentApi(runtime: runtime);
    });

    tearDown(() async {
      await runtime.dispose();
    });

    test('getResult with unknown handle throws ArgumentError', () {
      expect(
        () => agentApi.getResult(9999),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('waitAll with unknown handle throws ArgumentError', () {
      expect(
        () => agentApi.waitAll([9999]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('cancelAgent with unknown handle throws ArgumentError', () {
      expect(
        () => agentApi.cancelAgent(9999),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
