import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain show Running;
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/models/run_handle.dart';

void main() {
  group('RunHandle', () {
    late StreamController<BaseEvent> eventStreamController;
    late CancelToken cancelToken;
    late StreamSubscription<BaseEvent> subscription;

    setUp(() {
      eventStreamController = StreamController<BaseEvent>();
      cancelToken = CancelToken();
      subscription = eventStreamController.stream.listen((_) {});
    });

    tearDown(() {
      eventStreamController.close();
    });

    group('construction', () {
      test('creates with required fields', () {
        final handle = RunHandle(
          roomId: 'room-1',
          threadId: 'thread-1',
          cancelToken: cancelToken,
          subscription: subscription,
        );

        expect(handle.roomId, 'room-1');
        expect(handle.threadId, 'thread-1');
        expect(handle.cancelToken, cancelToken);
        expect(handle.subscription, subscription);
      });

      test('defaults to IdleState when no initial state provided', () {
        final handle = RunHandle(
          roomId: 'room-1',
          threadId: 'thread-1',
          cancelToken: cancelToken,
          subscription: subscription,
        );

        expect(handle.state, isA<IdleState>());
      });

      test('accepts initial state', () {
        const conversation = Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );
        const runningState = RunningState(conversation: conversation);

        final handle = RunHandle(
          roomId: 'room-1',
          threadId: 'thread-1',
          cancelToken: cancelToken,
          subscription: subscription,
          initialState: runningState,
        );

        expect(handle.state, isA<RunningState>());
      });
    });

    group('key', () {
      test('returns composite key of roomId:threadId', () {
        final handle = RunHandle(
          roomId: 'room-123',
          threadId: 'thread-456',
          cancelToken: cancelToken,
          subscription: subscription,
        );

        expect(handle.key, 'room-123:thread-456');
      });

      test('handles special characters in IDs', () {
        final handle = RunHandle(
          roomId: 'room-with-dashes',
          threadId: 'thread_with_underscores',
          cancelToken: cancelToken,
          subscription: subscription,
        );

        expect(handle.key, 'room-with-dashes:thread_with_underscores');
      });
    });

    group('state', () {
      test('state can be updated', () {
        final handle = RunHandle(
          roomId: 'room-1',
          threadId: 'thread-1',
          cancelToken: cancelToken,
          subscription: subscription,
        );

        const conversation = Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );
        const runningState = RunningState(conversation: conversation);

        handle.state = runningState;

        expect(handle.state, isA<RunningState>());
      });
    });

    group('isActive', () {
      test('returns false when state is IdleState', () {
        final handle = RunHandle(
          roomId: 'room-1',
          threadId: 'thread-1',
          cancelToken: cancelToken,
          subscription: subscription,
        );

        expect(handle.isActive, isFalse);
      });

      test('returns true when state is RunningState', () {
        const conversation = Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );
        const runningState = RunningState(conversation: conversation);

        final handle = RunHandle(
          roomId: 'room-1',
          threadId: 'thread-1',
          cancelToken: cancelToken,
          subscription: subscription,
          initialState: runningState,
        );

        expect(handle.isActive, isTrue);
      });

      test('returns false when state is CompletedState', () {
        const conversation = Conversation(
          threadId: 'thread-1',
          status: Completed(),
        );
        const completedState = CompletedState(
          conversation: conversation,
          result: Success(),
        );

        final handle = RunHandle(
          roomId: 'room-1',
          threadId: 'thread-1',
          cancelToken: cancelToken,
          subscription: subscription,
          initialState: completedState,
        );

        expect(handle.isActive, isFalse);
      });
    });

    group('dispose', () {
      test('cancels the cancel token', () async {
        final handle = RunHandle(
          roomId: 'room-1',
          threadId: 'thread-1',
          cancelToken: cancelToken,
          subscription: subscription,
        );

        expect(cancelToken.isCancelled, isFalse);

        await handle.dispose();

        expect(cancelToken.isCancelled, isTrue);
      });

      test('cancels the subscription', () async {
        var eventReceived = false;
        // Use a broadcast stream to allow multiple listeners
        final broadcastController = StreamController<BaseEvent>.broadcast();
        final testSubscription = broadcastController.stream.listen((_) {
          eventReceived = true;
        });

        addTearDown(testSubscription.cancel);
        addTearDown(broadcastController.close);

        final handle = RunHandle(
          roomId: 'room-1',
          threadId: 'thread-1',
          cancelToken: cancelToken,
          subscription: testSubscription,
        );

        await handle.dispose();

        // After dispose, adding events should not trigger the listener
        broadcastController.add(
          const RunStartedEvent(threadId: 'thread-1', runId: 'run-1'),
        );
        await Future<void>.delayed(Duration.zero);

        expect(eventReceived, isFalse);
      });

      test('can be called multiple times safely', () async {
        final handle = RunHandle(
          roomId: 'room-1',
          threadId: 'thread-1',
          cancelToken: cancelToken,
          subscription: subscription,
        );

        // Should not throw when called multiple times
        await handle.dispose();
        await handle.dispose();
        await handle.dispose();

        expect(cancelToken.isCancelled, isTrue);
      });

      test('second dispose does not cancel subscription again', () async {
        var cancelCount = 0;
        final broadcastController = StreamController<BaseEvent>.broadcast();
        final testSubscription = broadcastController.stream.listen((_) {});

        addTearDown(testSubscription.cancel);
        addTearDown(broadcastController.close);

        broadcastController.onCancel = () {
          cancelCount++;
        };

        final handle = RunHandle(
          roomId: 'room-1',
          threadId: 'thread-1',
          cancelToken: cancelToken,
          subscription: testSubscription,
        );

        await handle.dispose();
        expect(cancelCount, 1);

        // Second dispose should be a no-op
        await handle.dispose();
        expect(cancelCount, 1);
      });
    });

    group('toString', () {
      test('includes key and state', () {
        final handle = RunHandle(
          roomId: 'room-1',
          threadId: 'thread-1',
          cancelToken: cancelToken,
          subscription: subscription,
        );

        final str = handle.toString();

        expect(str, contains('RunHandle'));
        expect(str, contains('key: room-1:thread-1'));
        expect(str, contains('IdleState'));
      });
    });
  });
}
