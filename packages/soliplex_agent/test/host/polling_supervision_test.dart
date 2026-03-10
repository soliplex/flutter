import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Stateful fake that supports per-handle status progression.
//
// Each handle gets a list of statuses returned in order. Once exhausted,
// the last status is returned forever (sticky). This models the real
// lifecycle: 'spawning' → 'running' → 'completed' (or 'failed').
// ---------------------------------------------------------------------------

class _PollingAgentApi extends FakeAgentApi {
  final Map<int, List<String>> _statusSequences = {};
  final Map<int, int> _statusIndex = {};
  final Map<int, String> _results = {};

  void setStatusSequence(int handle, List<String> sequence) {
    _statusSequences[handle] = sequence;
    _statusIndex[handle] = 0;
  }

  void setResult(int handle, String result) {
    _results[handle] = result;
  }

  @override
  String agentStatus(int handle) {
    calls['agentStatus'] = [handle];
    final seq = _statusSequences[handle];
    if (seq == null) return super.agentStatus(handle);
    final idx = _statusIndex[handle]!;
    final status = seq[idx.clamp(0, seq.length - 1)];
    if (idx < seq.length - 1) _statusIndex[handle] = idx + 1;
    return status;
  }

  @override
  Future<String> getResult(int handle, {Duration? timeout}) async {
    calls['getResult'] = [handle, timeout];
    final result = _results[handle];
    if (result != null) return result;
    return super.getResult(handle, timeout: timeout);
  }
}

// ---------------------------------------------------------------------------
// Polling supervision helper — mirrors what Python would do.
//
// This is the Dart equivalent of the pattern we expect the LLM to generate:
//
//   while True:
//       s = agent_status(handle)
//       if s in ("completed", "failed", "cancelled"):
//           break
//       sleep(poll_ms)
// ---------------------------------------------------------------------------

/// Terminal states that end polling.
const _terminalStates = {'completed', 'failed', 'cancelled'};

/// Polls `agentApi.agentStatus` until a terminal state or [maxPolls] reached.
Future<String> pollUntilDone(
  AgentApi agentApi,
  int handle, {
  int maxPolls = 20,
}) async {
  for (var i = 0; i < maxPolls; i++) {
    final status = agentApi.agentStatus(handle);
    if (_terminalStates.contains(status)) return status;
    // In real code this would be sleep(500). In tests we yield the event loop.
    await Future<void>.delayed(Duration.zero);
  }
  return 'poll_timeout';
}

void main() {
  // =========================================================================
  // 1. Spawn + poll + get_result — happy path
  // =========================================================================
  group('polling supervision - happy path', () {
    test('spawn two workers, poll until completed, collect results', () async {
      final agent = _PollingAgentApi();

      // Spawn two workers.
      final h1 = await agent.spawnAgent('chat', 'task A');
      final h2 = await agent.spawnAgent('chat', 'task B');
      expect(h1, 1);
      expect(h2, 2);

      // Configure lifecycle: running → running → completed.
      agent
        ..setStatusSequence(h1, ['running', 'running', 'completed'])
        ..setStatusSequence(h2, ['running', 'completed'])
        ..setResult(h1, 'result-A')
        ..setResult(h2, 'result-B');

      // Poll both until done.
      final s1 = await pollUntilDone(agent, h1);
      final s2 = await pollUntilDone(agent, h2);
      expect(s1, 'completed');
      expect(s2, 'completed');

      // Collect results.
      final r1 = await agent.getResult(h1);
      final r2 = await agent.getResult(h2);
      expect(r1, 'result-A');
      expect(r2, 'result-B');
    });

    test('single worker completes immediately on first poll', () async {
      final agent = _PollingAgentApi();
      final h = await agent.spawnAgent('chat', 'quick task');

      agent
        ..setStatusSequence(h, ['completed'])
        ..setResult(h, 'done');

      final status = await pollUntilDone(agent, h);
      expect(status, 'completed');

      final result = await agent.getResult(h);
      expect(result, 'done');
    });
  });

  // =========================================================================
  // 2. Blackboard coordination
  // =========================================================================
  group('polling supervision - blackboard coordination', () {
    test('workers write results, supervisor aggregates', () async {
      final agent = _PollingAgentApi();
      final blackboard = FakeBlackboardApi();

      // Spawn workers.
      final h1 = await agent.spawnAgent('chat', 'fetch price');
      final h2 = await agent.spawnAgent('chat', 'fetch volume');

      agent
        ..setStatusSequence(h1, ['running', 'completed'])
        ..setStatusSequence(h2, ['running', 'running', 'completed'])
        ..setResult(h1, '42.50')
        ..setResult(h2, '1000000');

      // Poll until both done.
      final s1 = await pollUntilDone(agent, h1);
      final s2 = await pollUntilDone(agent, h2);
      expect(s1, 'completed');
      expect(s2, 'completed');

      // Supervisor reads results and writes aggregated data to blackboard.
      final r1 = await agent.getResult(h1);
      final r2 = await agent.getResult(h2);
      await blackboard.write('price', r1);
      await blackboard.write('volume', r2);
      await blackboard.write('summary', 'Price: $r1, Volume: $r2');

      // Verify blackboard state.
      expect(blackboard.store['price'], '42.50');
      expect(blackboard.store['volume'], '1000000');
      expect(blackboard.store['summary'], 'Price: 42.50, Volume: 1000000');
      expect(await blackboard.keys(), hasLength(3));
    });

    test('blackboard read returns null for missing key', () async {
      final blackboard = FakeBlackboardApi();
      final value = await blackboard.read('nonexistent');
      expect(value, isNull);
    });

    test('blackboard write overwrites existing value', () async {
      final blackboard = FakeBlackboardApi();
      await blackboard.write('key', 'v1');
      await blackboard.write('key', 'v2');
      expect(await blackboard.read('key'), 'v2');
    });
  });

  // =========================================================================
  // 3. Failure detection + retry
  // =========================================================================
  group('polling supervision - failure and retry', () {
    test('detects failed worker and respawns', () async {
      final agent = _PollingAgentApi();

      // First attempt fails.
      final h1 = await agent.spawnAgent('chat', 'flaky task');
      agent.setStatusSequence(h1, ['running', 'failed']);

      final s1 = await pollUntilDone(agent, h1);
      expect(s1, 'failed');

      // Supervisor cancels the failed handle and retries.
      await agent.cancelAgent(h1);

      // Second attempt succeeds.
      final h2 = await agent.spawnAgent('chat', 'flaky task');
      agent
        ..setStatusSequence(h2, ['running', 'completed'])
        ..setResult(h2, 'retry-success');

      final s2 = await pollUntilDone(agent, h2);
      expect(s2, 'completed');
      expect(await agent.getResult(h2), 'retry-success');
    });

    test('retries up to max attempts then gives up', () async {
      final agent = _PollingAgentApi();
      const maxRetries = 3;
      var attempts = 0;
      String? finalResult;

      for (var retry = 0; retry <= maxRetries; retry++) {
        attempts++;
        final h = await agent.spawnAgent('chat', 'always-fail');
        // All attempts fail except the last.
        if (retry < maxRetries) {
          agent.setStatusSequence(h, ['failed']);
        } else {
          agent
            ..setStatusSequence(h, ['completed'])
            ..setResult(h, 'finally-worked');
        }

        final status = await pollUntilDone(agent, h);
        if (status == 'completed') {
          finalResult = await agent.getResult(h);
          break;
        }
      }

      expect(attempts, maxRetries + 1);
      expect(finalResult, 'finally-worked');
    });
  });

  // =========================================================================
  // 4. Timeout + cancel
  // =========================================================================
  group('polling supervision - timeout and cancel', () {
    test('cancels worker that never completes', () async {
      final agent = _PollingAgentApi();
      final h = await agent.spawnAgent('chat', 'stuck task');

      // Worker stays running forever.
      agent.setStatusSequence(h, ['running']);

      // Poll with low max to simulate timeout.
      final status = await pollUntilDone(agent, h, maxPolls: 5);
      expect(status, 'poll_timeout');

      // Supervisor cancels the stuck worker.
      final cancelled = await agent.cancelAgent(h);
      expect(cancelled, isTrue);
    });

    test('cancels one stuck worker while collecting another', () async {
      final agent = _PollingAgentApi();

      final h1 = await agent.spawnAgent('chat', 'fast task');
      final h2 = await agent.spawnAgent('chat', 'stuck task');

      agent
        ..setStatusSequence(h1, ['running', 'completed'])
        ..setResult(h1, 'fast-result')
        ..setStatusSequence(h2, ['running']); // Never completes.

      final s1 = await pollUntilDone(agent, h1);
      expect(s1, 'completed');

      final s2 = await pollUntilDone(agent, h2, maxPolls: 3);
      expect(s2, 'poll_timeout');

      // Collect the good result, cancel the stuck one.
      final r1 = await agent.getResult(h1);
      expect(r1, 'fast-result');
      await agent.cancelAgent(h2);
    });
  });

  // =========================================================================
  // 5. Mixed outcomes
  // =========================================================================
  group('polling supervision - mixed outcomes', () {
    test('handles mix of success, failure, and cancel', () async {
      final agent = _PollingAgentApi();
      final blackboard = FakeBlackboardApi();

      final h1 = await agent.spawnAgent('chat', 'task-ok');
      final h2 = await agent.spawnAgent('chat', 'task-fail');
      final h3 = await agent.spawnAgent('chat', 'task-slow');

      agent
        ..setStatusSequence(h1, ['running', 'completed'])
        ..setResult(h1, 'ok-result')
        ..setStatusSequence(h2, ['running', 'failed'])
        ..setStatusSequence(h3, ['running']); // Never finishes.

      // Poll all three.
      final results = <int, String>{};
      final failures = <int>[];
      final timeouts = <int>[];

      for (final h in [h1, h2, h3]) {
        final status = await pollUntilDone(agent, h, maxPolls: 5);
        switch (status) {
          case 'completed':
            results[h] = await agent.getResult(h);
          case 'failed':
            failures.add(h);
          case 'poll_timeout':
            timeouts.add(h);
            await agent.cancelAgent(h);
          default:
            fail('Unexpected status: $status');
        }
      }

      expect(results, {h1: 'ok-result'});
      expect(failures, [h2]);
      expect(timeouts, [h3]);

      // Write summary to blackboard.
      await blackboard.write('successes', results.length);
      await blackboard.write('failures', failures.length);
      await blackboard.write('timeouts', timeouts.length);

      expect(blackboard.store['successes'], 1);
      expect(blackboard.store['failures'], 1);
      expect(blackboard.store['timeouts'], 1);
    });

    test('fan-out to 5 workers, aggregate partial results', () async {
      final agent = _PollingAgentApi();
      final blackboard = FakeBlackboardApi();
      const workerCount = 5;

      // Spawn 5 workers with varying completion times.
      final handles = <int>[];
      for (var i = 0; i < workerCount; i++) {
        final h = await agent.spawnAgent('chat', 'worker-$i');
        handles.add(h);
        // Workers complete after 1..5 poll cycles.
        final statuses = [...List.filled(i + 1, 'running'), 'completed'];
        agent
          ..setStatusSequence(h, statuses)
          ..setResult(h, 'output-$i');
      }

      // Poll all workers.
      final outputs = <String>[];
      for (final h in handles) {
        final status = await pollUntilDone(agent, h);
        expect(status, 'completed');
        outputs.add(await agent.getResult(h));
      }

      expect(outputs, hasLength(workerCount));
      for (var i = 0; i < workerCount; i++) {
        expect(outputs[i], 'output-$i');
      }

      // Write aggregated result.
      await blackboard.write('all_outputs', outputs);
      expect(blackboard.store['all_outputs'], [
        'output-0',
        'output-1',
        'output-2',
        'output-3',
        'output-4',
      ]);
    });
  });

  // =========================================================================
  // 6. Supervision tree depth (supervisor spawns sub-supervisor)
  // =========================================================================
  group('polling supervision - nested supervision', () {
    test('supervisor polls sub-supervisor which polls workers', () async {
      // This tests the pattern at 2 levels:
      // L1 supervisor → L2 sub-supervisor → L3 workers (via non-Python rooms)
      //
      // In production, L1 is Python, L2 is a chat room, L3 is chat rooms.
      // L1 Python polls L2 status, L2 internally manages L3.
      // Here we simulate L1 polling L2.
      final agent = _PollingAgentApi();
      final blackboard = FakeBlackboardApi();

      // L1: spawn sub-supervisor.
      final subSupervisor = await agent.spawnAgent(
        'chat',
        'You are a sub-supervisor. Spawn 2 workers and aggregate.',
      );

      // Simulate sub-supervisor running for a few cycles then completing.
      agent
        ..setStatusSequence(subSupervisor, [
          'spawning',
          'running',
          'running',
          'running',
          'completed',
        ])
        ..setResult(subSupervisor, 'sub-supervisor aggregated: A=10, B=20');

      // L1: poll sub-supervisor.
      final status = await pollUntilDone(agent, subSupervisor);
      expect(status, 'completed');

      final result = await agent.getResult(subSupervisor);
      expect(result, contains('A=10'));
      expect(result, contains('B=20'));

      await blackboard.write('l2_result', result);
      expect(
        blackboard.store['l2_result'],
        'sub-supervisor aggregated: A=10, B=20',
      );
    });
  });
}
