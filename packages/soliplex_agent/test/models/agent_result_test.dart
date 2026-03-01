import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:test/test.dart';

const ThreadKey _key = (
  serverId: 'srv-1',
  roomId: 'room-a',
  threadId: 'thread-1',
);

const ThreadKey _otherKey = (
  serverId: 'srv-2',
  roomId: 'room-b',
  threadId: 'thread-2',
);

void main() {
  group('AgentSuccess', () {
    test('stores all fields', () {
      const result = AgentSuccess(
        threadKey: _key,
        output: 'hello',
        runId: 'run-1',
      );

      expect(result.threadKey, equals(_key));
      expect(result.output, equals('hello'));
      expect(result.runId, equals('run-1'));
    });

    test('equal instances are equal', () {
      const a = AgentSuccess(threadKey: _key, output: 'hello', runId: 'run-1');
      const b = AgentSuccess(threadKey: _key, output: 'hello', runId: 'run-1');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different output produces inequality', () {
      const a = AgentSuccess(threadKey: _key, output: 'hello', runId: 'run-1');
      const b = AgentSuccess(threadKey: _key, output: 'world', runId: 'run-1');

      expect(a, isNot(equals(b)));
    });

    test('different threadKey produces inequality', () {
      const a = AgentSuccess(threadKey: _key, output: 'hello', runId: 'run-1');
      const b = AgentSuccess(
        threadKey: _otherKey,
        output: 'hello',
        runId: 'run-1',
      );

      expect(a, isNot(equals(b)));
    });

    test('toString includes runId and threadKey', () {
      const result = AgentSuccess(
        threadKey: _key,
        output: 'hello',
        runId: 'run-1',
      );

      expect(result.toString(), contains('run-1'));
      expect(result.toString(), contains('AgentSuccess'));
    });
  });

  group('AgentFailure', () {
    test('stores all fields including partialOutput', () {
      const result = AgentFailure(
        threadKey: _key,
        reason: FailureReason.networkLost,
        error: 'connection dropped',
        partialOutput: 'partial',
      );

      expect(result.threadKey, equals(_key));
      expect(result.reason, equals(FailureReason.networkLost));
      expect(result.error, equals('connection dropped'));
      expect(result.partialOutput, equals('partial'));
    });

    test('partialOutput defaults to null', () {
      const result = AgentFailure(
        threadKey: _key,
        reason: FailureReason.serverError,
        error: 'boom',
      );

      expect(result.partialOutput, isNull);
    });

    test('equal instances are equal', () {
      const a = AgentFailure(
        threadKey: _key,
        reason: FailureReason.authExpired,
        error: '401',
      );
      const b = AgentFailure(
        threadKey: _key,
        reason: FailureReason.authExpired,
        error: '401',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different reason produces inequality', () {
      const a = AgentFailure(
        threadKey: _key,
        reason: FailureReason.authExpired,
        error: 'err',
      );
      const b = AgentFailure(
        threadKey: _key,
        reason: FailureReason.rateLimited,
        error: 'err',
      );

      expect(a, isNot(equals(b)));
    });

    test('toString includes reason and error', () {
      const result = AgentFailure(
        threadKey: _key,
        reason: FailureReason.networkLost,
        error: 'dropped',
      );

      expect(result.toString(), contains('networkLost'));
      expect(result.toString(), contains('dropped'));
      expect(result.toString(), contains('AgentFailure'));
    });
  });

  group('AgentTimedOut', () {
    test('stores elapsed and threadKey', () {
      const result = AgentTimedOut(
        threadKey: _key,
        elapsed: Duration(seconds: 30),
      );

      expect(result.threadKey, equals(_key));
      expect(result.elapsed, equals(const Duration(seconds: 30)));
    });

    test('equal instances are equal', () {
      const a = AgentTimedOut(threadKey: _key, elapsed: Duration(seconds: 30));
      const b = AgentTimedOut(threadKey: _key, elapsed: Duration(seconds: 30));

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different elapsed produces inequality', () {
      const a = AgentTimedOut(threadKey: _key, elapsed: Duration(seconds: 30));
      const b = AgentTimedOut(threadKey: _key, elapsed: Duration(seconds: 60));

      expect(a, isNot(equals(b)));
    });

    test('toString includes elapsed', () {
      const result = AgentTimedOut(
        threadKey: _key,
        elapsed: Duration(seconds: 30),
      );

      expect(result.toString(), contains('0:00:30'));
      expect(result.toString(), contains('AgentTimedOut'));
    });
  });

  group('AgentResult exhaustiveness', () {
    test('switch covers all subtypes', () {
      const results = <AgentResult>[
        AgentSuccess(threadKey: _key, output: 'ok', runId: 'r1'),
        AgentFailure(
          threadKey: _key,
          reason: FailureReason.serverError,
          error: 'err',
        ),
        AgentTimedOut(threadKey: _key, elapsed: Duration(seconds: 5)),
      ];

      for (final result in results) {
        final label = switch (result) {
          AgentSuccess() => 'success',
          AgentFailure() => 'failure',
          AgentTimedOut() => 'timeout',
        };
        expect(label, isNotEmpty);
      }
    });

    test('all subtypes share threadKey from base', () {
      const results = <AgentResult>[
        AgentSuccess(threadKey: _key, output: 'ok', runId: 'r1'),
        AgentFailure(
          threadKey: _key,
          reason: FailureReason.serverError,
          error: 'err',
        ),
        AgentTimedOut(threadKey: _key, elapsed: Duration(seconds: 5)),
      ];

      for (final result in results) {
        expect(result.threadKey, equals(_key));
      }
    });
  });
}
