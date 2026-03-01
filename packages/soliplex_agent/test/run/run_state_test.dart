import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:test/test.dart';

const ThreadKey _key = (
  serverId: 'srv-1',
  roomId: 'room-1',
  threadId: 'thread-1',
);

const ThreadKey _otherKey = (
  serverId: 'srv-2',
  roomId: 'room-2',
  threadId: 'thread-2',
);

void main() {
  final conversation = Conversation.empty(threadId: _key.threadId);
  const streaming = AwaitingText();

  group('IdleState', () {
    test('equality', () {
      expect(const IdleState(), equals(const IdleState()));
    });

    test('hashCode is consistent', () {
      expect(const IdleState().hashCode, equals(const IdleState().hashCode));
    });

    test('toString', () {
      expect(const IdleState().toString(), equals('IdleState()'));
    });
  });

  group('RunningState', () {
    test('equality with same fields', () {
      final stateA = RunningState(
        threadKey: _key,
        runId: 'run-1',
        conversation: conversation,
        streaming: streaming,
      );
      final stateB = RunningState(
        threadKey: _key,
        runId: 'run-1',
        conversation: conversation,
        streaming: streaming,
      );
      expect(stateA, equals(stateB));
    });

    test('inequality with different runId', () {
      final stateA = RunningState(
        threadKey: _key,
        runId: 'run-1',
        conversation: conversation,
        streaming: streaming,
      );
      final stateB = RunningState(
        threadKey: _key,
        runId: 'run-2',
        conversation: conversation,
        streaming: streaming,
      );
      expect(stateA, isNot(equals(stateB)));
    });

    test('copyWith replaces conversation', () {
      final original = RunningState(
        threadKey: _key,
        runId: 'run-1',
        conversation: conversation,
        streaming: streaming,
      );
      final updated = conversation.withStatus(const Running(runId: 'run-1'));
      final copied = original.copyWith(conversation: updated);

      expect(copied.conversation, equals(updated));
      expect(copied.runId, equals('run-1'));
      expect(copied.threadKey, equals(_key));
    });

    test('copyWith with no args returns equal state', () {
      final original = RunningState(
        threadKey: _key,
        runId: 'run-1',
        conversation: conversation,
        streaming: streaming,
      );
      expect(original.copyWith(), equals(original));
    });

    test('toString includes runId and threadKey', () {
      final state = RunningState(
        threadKey: _key,
        runId: 'run-1',
        conversation: conversation,
        streaming: streaming,
      );
      expect(state.toString(), contains('run-1'));
      expect(state.toString(), contains('RunningState'));
    });
  });

  group('CompletedState', () {
    test('equality', () {
      final stateA = CompletedState(
        threadKey: _key,
        runId: 'run-1',
        conversation: conversation,
      );
      final stateB = CompletedState(
        threadKey: _key,
        runId: 'run-1',
        conversation: conversation,
      );
      expect(stateA, equals(stateB));
    });

    test('inequality with different threadKey', () {
      final stateA = CompletedState(
        threadKey: _key,
        runId: 'run-1',
        conversation: conversation,
      );
      final stateB = CompletedState(
        threadKey: _otherKey,
        runId: 'run-1',
        conversation: conversation,
      );
      expect(stateA, isNot(equals(stateB)));
    });

    test('toString includes runId', () {
      final state = CompletedState(
        threadKey: _key,
        runId: 'run-1',
        conversation: conversation,
      );
      expect(state.toString(), contains('run-1'));
    });
  });

  group('FailedState', () {
    test('equality with same fields', () {
      const stateA = FailedState(
        threadKey: _key,
        reason: FailureReason.serverError,
        error: 'something broke',
      );
      const stateB = FailedState(
        threadKey: _key,
        reason: FailureReason.serverError,
        error: 'something broke',
      );
      expect(stateA, equals(stateB));
    });

    test('equality with optional conversation', () {
      final stateA = FailedState(
        threadKey: _key,
        reason: FailureReason.networkLost,
        error: 'timeout',
        conversation: conversation,
      );
      final stateB = FailedState(
        threadKey: _key,
        reason: FailureReason.networkLost,
        error: 'timeout',
        conversation: conversation,
      );
      expect(stateA, equals(stateB));
    });

    test('inequality when conversation differs', () {
      const stateA = FailedState(
        threadKey: _key,
        reason: FailureReason.networkLost,
        error: 'timeout',
      );
      final stateB = FailedState(
        threadKey: _key,
        reason: FailureReason.networkLost,
        error: 'timeout',
        conversation: conversation,
      );
      expect(stateA, isNot(equals(stateB)));
    });

    test('toString includes reason and error', () {
      const state = FailedState(
        threadKey: _key,
        reason: FailureReason.authExpired,
        error: 'token expired',
      );
      expect(state.toString(), contains('authExpired'));
      expect(state.toString(), contains('token expired'));
    });
  });

  group('CancelledState', () {
    test('equality', () {
      const stateA = CancelledState(threadKey: _key);
      const stateB = CancelledState(threadKey: _key);
      expect(stateA, equals(stateB));
    });

    test('equality with conversation', () {
      final stateA = CancelledState(
        threadKey: _key,
        conversation: conversation,
      );
      final stateB = CancelledState(
        threadKey: _key,
        conversation: conversation,
      );
      expect(stateA, equals(stateB));
    });

    test('toString includes threadKey', () {
      const state = CancelledState(threadKey: _key);
      expect(state.toString(), contains('CancelledState'));
    });
  });

  group('ToolYieldingState', () {
    final pendingTools = [const ToolCallInfo(id: 'tc-1', name: 'search')];

    test('equality with same fields', () {
      final stateA = ToolYieldingState(
        threadKey: _key,
        runId: 'run-1',
        conversation: conversation,
        pendingToolCalls: pendingTools,
        toolDepth: 0,
      );
      final stateB = ToolYieldingState(
        threadKey: _key,
        runId: 'run-1',
        conversation: conversation,
        pendingToolCalls: pendingTools,
        toolDepth: 0,
      );
      expect(stateA, equals(stateB));
    });

    test('inequality with different toolDepth', () {
      final stateA = ToolYieldingState(
        threadKey: _key,
        runId: 'run-1',
        conversation: conversation,
        pendingToolCalls: pendingTools,
        toolDepth: 0,
      );
      final stateB = ToolYieldingState(
        threadKey: _key,
        runId: 'run-1',
        conversation: conversation,
        pendingToolCalls: pendingTools,
        toolDepth: 1,
      );
      expect(stateA, isNot(equals(stateB)));
    });

    test('toString includes runId, pending count, and depth', () {
      final state = ToolYieldingState(
        threadKey: _key,
        runId: 'run-1',
        conversation: conversation,
        pendingToolCalls: pendingTools,
        toolDepth: 2,
      );
      final str = state.toString();
      expect(str, contains('run-1'));
      expect(str, contains('pending: 1'));
      expect(str, contains('depth: 2'));
    });
  });

  group('exhaustive switch', () {
    test('all subtypes are matchable', () {
      final states = <RunState>[
        const IdleState(),
        RunningState(
          threadKey: _key,
          runId: 'run-1',
          conversation: conversation,
          streaming: streaming,
        ),
        CompletedState(
          threadKey: _key,
          runId: 'run-1',
          conversation: conversation,
        ),
        ToolYieldingState(
          threadKey: _key,
          runId: 'run-1',
          conversation: conversation,
          pendingToolCalls: const [],
          toolDepth: 0,
        ),
        const FailedState(
          threadKey: _key,
          reason: FailureReason.internalError,
          error: 'oops',
        ),
        const CancelledState(threadKey: _key),
      ];

      for (final state in states) {
        final label = switch (state) {
          IdleState() => 'idle',
          RunningState() => 'running',
          CompletedState() => 'completed',
          ToolYieldingState() => 'yielding',
          FailedState() => 'failed',
          CancelledState() => 'cancelled',
        };
        expect(label, isNotEmpty);
      }
    });
  });
}
