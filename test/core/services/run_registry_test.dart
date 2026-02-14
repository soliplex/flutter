import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain
    show Completed, Failed, Running;
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/models/run_handle.dart';
import 'package:soliplex_frontend/core/models/run_lifecycle_event.dart';
import 'package:soliplex_frontend/core/services/run_registry.dart';

void main() {
  group('RunRegistry', () {
    late RunRegistry registry;

    setUp(() {
      registry = RunRegistry();
    });

    tearDown(() async {
      await registry.dispose();
    });

    RunHandle createHandle({
      String roomId = 'room-1',
      String threadId = 'thread-1',
      ActiveRunState? initialState,
    }) {
      final controller = StreamController<BaseEvent>();
      final cancelToken = CancelToken();
      final subscription = controller.stream.listen((_) {});

      // Cleanup handled by registry.dispose() and addTearDown
      addTearDown(subscription.cancel);
      addTearDown(controller.close);

      return RunHandle(
        key: (roomId: roomId, threadId: threadId),
        runId: 'run-1',
        cancelToken: cancelToken,
        subscription: subscription,
        userMessageId: 'user_1',
        previousAguiState: const {},
        initialState: initialState,
      );
    }

    const defaultKey = (roomId: 'room-1', threadId: 'thread-1');

    group('registerRun', () {
      test('adds handle to registry', () async {
        final handle = createHandle();

        await registry.registerRun(handle);

        expect(registry.runCount, 1);
        expect(registry.hasRun(defaultKey), isTrue);
      });

      test('can register multiple handles for different threads', () async {
        final handle1 = createHandle();
        final handle2 = createHandle(threadId: 'thread-2');
        final handle3 = createHandle(roomId: 'room-2');

        await registry.registerRun(handle1);
        await registry.registerRun(handle2);
        await registry.registerRun(handle3);

        expect(registry.runCount, 3);
      });

      test('replaces existing handle for same room/thread', () async {
        final handle1 = createHandle();
        final handle2 = createHandle();

        await registry.registerRun(handle1);
        await registry.registerRun(handle2);

        expect(registry.runCount, 1);
        expect(handle1.cancelToken.isCancelled, isTrue);
      });
    });

    group('getRunState', () {
      test('returns null for unknown thread', () {
        final state = registry.getRunState(defaultKey);

        expect(state, isNull);
      });

      test('returns state for registered thread', () async {
        const conversation = Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );
        const runningState = RunningState(conversation: conversation);
        final handle = createHandle(initialState: runningState);

        await registry.registerRun(handle);

        final state = registry.getRunState(defaultKey);
        expect(state, isA<RunningState>());
      });

      test('reflects updated state', () async {
        final handle = createHandle();
        await registry.registerRun(handle);

        const conversation = Conversation(
          threadId: 'thread-1',
          status: domain.Running(runId: 'run-1'),
        );
        handle.state = const RunningState(conversation: conversation);

        final state = registry.getRunState(defaultKey);
        expect(state, isA<RunningState>());
      });
    });

    group('getHandle', () {
      test('returns null for unknown thread', () {
        final handle = registry.getHandle(defaultKey);

        expect(handle, isNull);
      });

      test('returns handle for registered thread', () async {
        final handle = createHandle();
        await registry.registerRun(handle);

        final retrieved = registry.getHandle(defaultKey);
        expect(retrieved, same(handle));
      });
    });

    group('hasRun', () {
      test('returns false for unknown thread', () {
        expect(registry.hasRun(defaultKey), isFalse);
      });

      test('returns true for registered thread', () async {
        final handle = createHandle();
        await registry.registerRun(handle);

        expect(registry.hasRun(defaultKey), isTrue);
      });

      test('returns false after run is removed', () async {
        final handle = createHandle();
        await registry.registerRun(handle);
        await registry.removeRun(defaultKey);

        expect(registry.hasRun(defaultKey), isFalse);
      });
    });

    group('hasActiveRun', () {
      test('returns false for unknown key', () {
        expect(registry.hasActiveRun(defaultKey), isFalse);
      });

      test('returns true for running handle', () async {
        final handle = createHandle(
          initialState: const RunningState(
            conversation: Conversation(
              threadId: 'thread-1',
              status: domain.Running(runId: 'run-1'),
            ),
          ),
        );
        await registry.registerRun(handle);

        expect(registry.hasActiveRun(defaultKey), isTrue);
      });

      test('returns false for completed handle', () async {
        final handle = createHandle();
        await registry.registerRun(handle);
        registry.completeRun(
          handle,
          const CompletedState(
            conversation: Conversation(
              threadId: 'thread-1',
              status: domain.Completed(),
            ),
            result: Success(),
          ),
        );

        expect(registry.hasRun(defaultKey), isTrue);
        expect(registry.hasActiveRun(defaultKey), isFalse);
      });
    });

    group('removeRun', () {
      test('removes handle from registry', () async {
        final handle = createHandle();
        await registry.registerRun(handle);

        await registry.removeRun(defaultKey);

        expect(registry.runCount, 0);
        expect(registry.hasRun(defaultKey), isFalse);
      });

      test('disposes the handle', () async {
        final handle = createHandle();
        await registry.registerRun(handle);

        await registry.removeRun(defaultKey);

        expect(handle.cancelToken.isCancelled, isTrue);
      });

      test('does nothing for unknown thread', () async {
        // Should not throw
        await registry
            .removeRun((roomId: 'room-1', threadId: 'unknown-thread'));

        expect(registry.runCount, 0);
      });

      test('only cancels specified thread', () async {
        final handle1 = createHandle();
        final handle2 = createHandle(threadId: 'thread-2');
        await registry.registerRun(handle1);
        await registry.registerRun(handle2);

        await registry.removeRun(defaultKey);

        expect(registry.runCount, 1);
        expect(registry.hasRun(defaultKey), isFalse);
        expect(
          registry.hasRun((roomId: 'room-1', threadId: 'thread-2')),
          isTrue,
        );
      });
    });

    group('removeAll', () {
      test('removes all handles', () async {
        final handle1 = createHandle();
        final handle2 = createHandle(threadId: 'thread-2');
        final handle3 = createHandle(roomId: 'room-2');
        await registry.registerRun(handle1);
        await registry.registerRun(handle2);
        await registry.registerRun(handle3);

        await registry.removeAll();

        expect(registry.runCount, 0);
      });

      test('disposes all handles', () async {
        final handle1 = createHandle();
        final handle2 = createHandle(threadId: 'thread-2');
        await registry.registerRun(handle1);
        await registry.registerRun(handle2);

        await registry.removeAll();

        expect(handle1.cancelToken.isCancelled, isTrue);
        expect(handle2.cancelToken.isCancelled, isTrue);
      });

      test('can be called on empty registry', () async {
        // Should not throw
        await registry.removeAll();

        expect(registry.runCount, 0);
      });
    });

    group('runCount', () {
      test('returns 0 for empty registry', () {
        expect(registry.runCount, 0);
      });

      test('reflects number of registered runs', () async {
        await registry.registerRun(createHandle());
        expect(registry.runCount, 1);

        await registry.registerRun(createHandle(threadId: 'thread-2'));
        expect(registry.runCount, 2);

        await registry.removeRun(defaultKey);
        expect(registry.runCount, 1);
      });
    });

    group('activeRunCount', () {
      test('returns 0 for empty registry', () {
        expect(registry.activeRunCount, 0);
      });

      test('counts only running handles, not completed ones', () async {
        final handle1 = createHandle(
          initialState: const RunningState(
            conversation: Conversation(
              threadId: 'thread-1',
              status: domain.Running(runId: 'run-1'),
            ),
          ),
        );
        final handle2 = createHandle(
          threadId: 'thread-2',
          initialState: const RunningState(
            conversation: Conversation(
              threadId: 'thread-2',
              status: domain.Running(runId: 'run-2'),
            ),
          ),
        );
        await registry.registerRun(handle1);
        await registry.registerRun(handle2);

        expect(registry.activeRunCount, 2);
        expect(registry.runCount, 2);

        registry.completeRun(
          handle1,
          const CompletedState(
            conversation: Conversation(
              threadId: 'thread-1',
              status: domain.Completed(),
            ),
            result: Success(),
          ),
        );

        expect(registry.activeRunCount, 1);
        expect(registry.runCount, 2);
      });
    });

    group('handles', () {
      test('returns empty iterable for empty registry', () {
        expect(registry.handles, isEmpty);
      });

      test('returns all registered handles', () async {
        final handle1 = createHandle();
        final handle2 = createHandle(threadId: 'thread-2');
        await registry.registerRun(handle1);
        await registry.registerRun(handle2);

        expect(registry.handles, containsAll([handle1, handle2]));
      });
    });

    group('dispose', () {
      test('cancels all runs', () async {
        final handle1 = createHandle();
        final handle2 = createHandle(threadId: 'thread-2');
        await registry.registerRun(handle1);
        await registry.registerRun(handle2);

        await registry.dispose();

        expect(handle1.cancelToken.isCancelled, isTrue);
        expect(handle2.cancelToken.isCancelled, isTrue);
        expect(registry.runCount, 0);
      });
    });

    group('composite key', () {
      test('same threadId in different rooms are distinct', () async {
        final handle1 = createHandle(roomId: 'room-A');
        final handle2 = createHandle(roomId: 'room-B');

        await registry.registerRun(handle1);
        await registry.registerRun(handle2);

        expect(registry.runCount, 2);
        expect(
          registry.hasRun((roomId: 'room-A', threadId: 'thread-1')),
          isTrue,
        );
        expect(
          registry.hasRun((roomId: 'room-B', threadId: 'thread-1')),
          isTrue,
        );
      });
    });

    group('lifecycle events', () {
      test('emits RunStarted when registerRun is called', () async {
        final handle = createHandle();

        final events = <RunLifecycleEvent>[];
        registry.lifecycleEvents.listen(events.add);

        await registry.registerRun(handle);

        expect(events, hasLength(1));
        expect(events.first, isA<RunStarted>());
        final started = events.first as RunStarted;
        expect(started.roomId, 'room-1');
        expect(started.threadId, 'thread-1');
      });

      test('replacing a handle emits RunStarted but no RunCompleted for old',
          () async {
        final handle1 = createHandle();
        final handle2 = createHandle();

        final events = <RunLifecycleEvent>[];
        registry.lifecycleEvents.listen(events.add);

        await registry.registerRun(handle1);
        await registry.registerRun(handle2);
        await Future<void>.delayed(Duration.zero);

        // Two RunStarted events, no RunCompleted for the replaced handle
        expect(events, hasLength(2));
        expect(events.every((e) => e is RunStarted), isTrue);
      });

      test('completeRun emits RunCompleted for Success', () async {
        const conversation = Conversation(
          threadId: 'thread-1',
          status: domain.Completed(),
        );
        const completed = CompletedState(
          conversation: conversation,
          result: Success(),
        );

        final handle = createHandle(
          initialState: const RunningState(
            conversation: Conversation(
              threadId: 'thread-1',
              status: domain.Running(runId: 'run-1'),
            ),
          ),
        );
        await registry.registerRun(handle);

        final events = <RunLifecycleEvent>[];
        registry.lifecycleEvents.listen(events.add);

        registry.completeRun(handle, completed);
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first, isA<RunCompleted>());
        final event = events.first as RunCompleted;
        expect(event.roomId, 'room-1');
        expect(event.threadId, 'thread-1');
        expect(event.result, isA<Success>());
      });

      test('completeRun emits RunCompleted for FailedResult', () async {
        const conversation = Conversation(
          threadId: 'thread-1',
          status: domain.Failed(error: 'boom'),
        );
        const completed = CompletedState(
          conversation: conversation,
          result: FailedResult(errorMessage: 'boom'),
        );

        final handle = createHandle(
          initialState: const RunningState(
            conversation: Conversation(
              threadId: 'thread-1',
              status: domain.Running(runId: 'run-1'),
            ),
          ),
        );
        await registry.registerRun(handle);

        final events = <RunLifecycleEvent>[];
        registry.lifecycleEvents.listen(events.add);

        registry.completeRun(handle, completed);
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        final event = events.first as RunCompleted;
        expect(event.result, isA<FailedResult>());
        expect(
          (event.result as FailedResult).errorMessage,
          'boom',
        );
      });

      test('completeRun emits RunCompleted for CancelledResult', () async {
        const conversation = Conversation(
          threadId: 'thread-1',
          status: domain.Completed(),
        );
        const completed = CompletedState(
          conversation: conversation,
          result: CancelledResult(reason: 'User cancelled'),
        );

        final handle = createHandle();
        await registry.registerRun(handle);

        final events = <RunLifecycleEvent>[];
        registry.lifecycleEvents.listen(events.add);

        registry.completeRun(handle, completed);
        await Future<void>.delayed(Duration.zero);

        expect(events, hasLength(1));
        expect(events.first, isA<RunCompleted>());
        final event = events.first as RunCompleted;
        expect(event.result, isA<CancelledResult>());
      });

      test('completeRun ignores stale handle replaced by a newer run',
          () async {
        final staleHandle = createHandle();
        await registry.registerRun(staleHandle);

        final newHandle = createHandle();
        await registry.registerRun(newHandle);

        final events = <RunLifecycleEvent>[];
        registry.lifecycleEvents.listen(events.add);

        registry.completeRun(
          staleHandle,
          const CompletedState(
            conversation: Conversation(
              threadId: 'thread-1',
              status: domain.Completed(),
            ),
            result: Success(),
          ),
        );

        expect(events, isEmpty);
        expect(staleHandle.state, isA<IdleState>());
      });

      test('completeRun after removeRun is a no-op', () async {
        final handle = createHandle();
        await registry.registerRun(handle);
        await registry.removeRun(defaultKey);

        final events = <RunLifecycleEvent>[];
        registry.lifecycleEvents.listen(events.add);

        registry.completeRun(
          handle,
          const CompletedState(
            conversation: Conversation(
              threadId: 'thread-1',
              status: domain.Completed(),
            ),
            result: Success(),
          ),
        );

        expect(events, isEmpty);
        expect(handle.state, isA<IdleState>());
      });

      test('completeRun sets handle state', () async {
        const conversation = Conversation(
          threadId: 'thread-1',
          status: domain.Completed(),
        );
        const completed = CompletedState(
          conversation: conversation,
          result: Success(),
        );

        final handle = createHandle();
        await registry.registerRun(handle);

        registry.completeRun(handle, completed);

        expect(handle.state, same(completed));
      });

      test('completeRun is no-op after disposal because handle is unregistered',
          () async {
        final handle = createHandle();
        await registry.registerRun(handle);

        await registry.dispose();

        // removeAll() cleared _runs, so identity check returns early
        registry.completeRun(
          handle,
          const CompletedState(
            conversation: Conversation(
              threadId: 'thread-1',
              status: domain.Completed(),
            ),
            result: Success(),
          ),
        );

        expect(handle.state, isA<IdleState>());
      });

      test('registerRun throws after disposal', () async {
        await registry.dispose();

        expect(
          () => registry.registerRun(createHandle()),
          throwsStateError,
        );
      });

      test('stream is closed on dispose', () async {
        var streamDone = false;
        registry.lifecycleEvents.listen(
          (_) {},
          onDone: () => streamDone = true,
        );

        await registry.dispose();

        expect(streamDone, isTrue);
      });
    });
  });
}
