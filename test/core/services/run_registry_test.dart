import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/soliplex_client.dart' as domain show Running;
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/models/run_handle.dart';
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
        roomId: roomId,
        threadId: threadId,
        runId: 'run-1',
        cancelToken: cancelToken,
        subscription: subscription,
        userMessageId: 'user_1',
        previousAguiState: const {},
        initialState: initialState,
      );
    }

    group('registerRun', () {
      test('adds handle to registry', () async {
        final handle = createHandle();

        await registry.registerRun(handle);

        expect(registry.activeRunCount, 1);
        expect(registry.hasActiveRun('room-1', 'thread-1'), isTrue);
      });

      test('can register multiple handles for different threads', () async {
        final handle1 = createHandle();
        final handle2 = createHandle(threadId: 'thread-2');
        final handle3 = createHandle(roomId: 'room-2');

        await registry.registerRun(handle1);
        await registry.registerRun(handle2);
        await registry.registerRun(handle3);

        expect(registry.activeRunCount, 3);
      });

      test('replaces existing handle for same room/thread', () async {
        final handle1 = createHandle();
        final handle2 = createHandle();

        await registry.registerRun(handle1);
        await registry.registerRun(handle2);

        expect(registry.activeRunCount, 1);
        expect(handle1.cancelToken.isCancelled, isTrue);
      });
    });

    group('getRunState', () {
      test('returns null for unknown thread', () {
        final state = registry.getRunState('room-1', 'thread-1');

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

        final state = registry.getRunState('room-1', 'thread-1');
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

        final state = registry.getRunState('room-1', 'thread-1');
        expect(state, isA<RunningState>());
      });
    });

    group('getHandle', () {
      test('returns null for unknown thread', () {
        final handle = registry.getHandle('room-1', 'thread-1');

        expect(handle, isNull);
      });

      test('returns handle for registered thread', () async {
        final handle = createHandle();
        await registry.registerRun(handle);

        final retrieved = registry.getHandle('room-1', 'thread-1');
        expect(retrieved, same(handle));
      });
    });

    group('hasActiveRun', () {
      test('returns false for unknown thread', () {
        expect(registry.hasActiveRun('room-1', 'thread-1'), isFalse);
      });

      test('returns true for registered thread', () async {
        final handle = createHandle();
        await registry.registerRun(handle);

        expect(registry.hasActiveRun('room-1', 'thread-1'), isTrue);
      });

      test('returns false after run is cancelled', () async {
        final handle = createHandle();
        await registry.registerRun(handle);
        await registry.cancelRun('room-1', 'thread-1');

        expect(registry.hasActiveRun('room-1', 'thread-1'), isFalse);
      });
    });

    group('cancelRun', () {
      test('removes handle from registry', () async {
        final handle = createHandle();
        await registry.registerRun(handle);

        await registry.cancelRun('room-1', 'thread-1');

        expect(registry.activeRunCount, 0);
        expect(registry.hasActiveRun('room-1', 'thread-1'), isFalse);
      });

      test('disposes the handle', () async {
        final handle = createHandle();
        await registry.registerRun(handle);

        await registry.cancelRun('room-1', 'thread-1');

        expect(handle.cancelToken.isCancelled, isTrue);
      });

      test('does nothing for unknown thread', () async {
        // Should not throw
        await registry.cancelRun('room-1', 'unknown-thread');

        expect(registry.activeRunCount, 0);
      });

      test('only cancels specified thread', () async {
        final handle1 = createHandle();
        final handle2 = createHandle(threadId: 'thread-2');
        await registry.registerRun(handle1);
        await registry.registerRun(handle2);

        await registry.cancelRun('room-1', 'thread-1');

        expect(registry.activeRunCount, 1);
        expect(registry.hasActiveRun('room-1', 'thread-1'), isFalse);
        expect(registry.hasActiveRun('room-1', 'thread-2'), isTrue);
      });
    });

    group('cancelAll', () {
      test('removes all handles', () async {
        final handle1 = createHandle();
        final handle2 = createHandle(threadId: 'thread-2');
        final handle3 = createHandle(roomId: 'room-2');
        await registry.registerRun(handle1);
        await registry.registerRun(handle2);
        await registry.registerRun(handle3);

        await registry.cancelAll();

        expect(registry.activeRunCount, 0);
      });

      test('disposes all handles', () async {
        final handle1 = createHandle();
        final handle2 = createHandle(threadId: 'thread-2');
        await registry.registerRun(handle1);
        await registry.registerRun(handle2);

        await registry.cancelAll();

        expect(handle1.cancelToken.isCancelled, isTrue);
        expect(handle2.cancelToken.isCancelled, isTrue);
      });

      test('can be called on empty registry', () async {
        // Should not throw
        await registry.cancelAll();

        expect(registry.activeRunCount, 0);
      });
    });

    group('activeRunCount', () {
      test('returns 0 for empty registry', () {
        expect(registry.activeRunCount, 0);
      });

      test('reflects number of registered runs', () async {
        await registry.registerRun(createHandle());
        expect(registry.activeRunCount, 1);

        await registry.registerRun(createHandle(threadId: 'thread-2'));
        expect(registry.activeRunCount, 2);

        await registry.cancelRun('room-1', 'thread-1');
        expect(registry.activeRunCount, 1);
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
        expect(registry.activeRunCount, 0);
      });
    });

    group('composite key', () {
      test('same threadId in different rooms are distinct', () async {
        final handle1 = createHandle(roomId: 'room-A');
        final handle2 = createHandle(roomId: 'room-B');

        await registry.registerRun(handle1);
        await registry.registerRun(handle2);

        expect(registry.activeRunCount, 2);
        expect(registry.hasActiveRun('room-A', 'thread-1'), isTrue);
        expect(registry.hasActiveRun('room-B', 'thread-1'), isTrue);
      });
    });
  });
}
