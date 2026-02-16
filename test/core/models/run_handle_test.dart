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
      subscription.cancel();
      eventStreamController.close();
    });

    RunHandle createHandle({
      ActiveRunState? initialState,
      StreamSubscription<BaseEvent>? customSubscription,
    }) =>
        RunHandle(
          key: (roomId: 'room-1', threadId: 'thread-1'),
          runId: 'run-1',
          cancelToken: cancelToken,
          subscription: customSubscription ?? subscription,
          userMessageId: 'user_1',
          previousAguiState: const {},
          initialState: initialState,
        );

    group('isActive', () {
      test('returns false when state is IdleState', () {
        final handle = createHandle();

        expect(handle.isActive, isFalse);
      });

      test('returns true when state is RunningState', () {
        const conversation = Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );

        final handle = createHandle(
          initialState: const RunningState(conversation: conversation),
        );

        expect(handle.isActive, isTrue);
      });

      test('returns false when state is CompletedState', () {
        const conversation = Conversation(
          threadId: 'thread-1',
          status: Completed(),
        );

        final handle = createHandle(
          initialState: const CompletedState(
            conversation: conversation,
            result: Success(),
          ),
        );

        expect(handle.isActive, isFalse);
      });
    });

    group('dispose', () {
      test('cancels the cancel token', () async {
        final handle = createHandle();

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

        final handle = createHandle(customSubscription: testSubscription);

        await handle.dispose();

        // After dispose, adding events should not trigger the listener
        broadcastController.add(
          const RunStartedEvent(threadId: 'thread-1', runId: 'run-1'),
        );
        await Future<void>.delayed(Duration.zero);

        expect(eventReceived, isFalse);
      });

      test('can be called multiple times safely', () async {
        final handle = createHandle();

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

        final handle = createHandle(customSubscription: testSubscription);

        await handle.dispose();
        expect(cancelCount, 1);

        // Second dispose should be a no-op
        await handle.dispose();
        expect(cancelCount, 1);
      });
    });
  });
}
