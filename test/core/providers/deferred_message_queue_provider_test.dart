import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/providers/deferred_message_queue_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeferredMessageQueueNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('starts with empty queue', () {
      final queue = container.read(deferredMessageQueueProvider);
      expect(queue, isEmpty);
    });

    test('enqueue adds message to queue', () {
      container.read(deferredMessageQueueProvider.notifier).enqueue(
            const DeferredMessage(
              targetKey: (roomId: 'room-1', threadId: 'thread-a'),
              message: 'hello',
            ),
          );

      final queue = container.read(deferredMessageQueueProvider);
      expect(queue, hasLength(1));
      expect(queue.first.message, 'hello');
      expect(queue.first.targetKey.threadId, 'thread-a');
    });

    test('pop returns messages in FIFO order', () {
      final notifier = container.read(deferredMessageQueueProvider.notifier)
        ..enqueue(
          const DeferredMessage(
            targetKey: (roomId: 'room-1', threadId: 'thread-a'),
            message: 'first',
          ),
        )
        ..enqueue(
          const DeferredMessage(
            targetKey: (roomId: 'room-1', threadId: 'thread-b'),
            message: 'second',
          ),
        )
        ..enqueue(
          const DeferredMessage(
            targetKey: (roomId: 'room-1', threadId: 'thread-c'),
            message: 'third',
          ),
        );

      expect(notifier.pop()!.message, 'first');
      expect(notifier.pop()!.message, 'second');
      expect(notifier.pop()!.message, 'third');
    });

    test('pop on empty queue returns null', () {
      final result =
          container.read(deferredMessageQueueProvider.notifier).pop();
      expect(result, isNull);
    });

    test('pop removes the message from the queue', () {
      container.read(deferredMessageQueueProvider.notifier).enqueue(
            const DeferredMessage(
              targetKey: (roomId: 'room-1', threadId: 'thread-a'),
              message: 'only',
            ),
          );

      final popped =
          container.read(deferredMessageQueueProvider.notifier).pop();
      expect(popped, isNotNull);

      final queue = container.read(deferredMessageQueueProvider);
      expect(queue, isEmpty);
    });

    test('clear empties the queue', () {
      container.read(deferredMessageQueueProvider.notifier)
        ..enqueue(
          const DeferredMessage(
            targetKey: (roomId: 'room-1', threadId: 'thread-a'),
            message: 'first',
          ),
        )
        ..enqueue(
          const DeferredMessage(
            targetKey: (roomId: 'room-1', threadId: 'thread-b'),
            message: 'second',
          ),
        )
        ..clear();

      final queue = container.read(deferredMessageQueueProvider);
      expect(queue, isEmpty);
    });
  });

  group('DeferredMessage', () {
    test('equality', () {
      const a = DeferredMessage(
        targetKey: (roomId: 'r1', threadId: 't1'),
        message: 'hello',
      );
      const b = DeferredMessage(
        targetKey: (roomId: 'r1', threadId: 't1'),
        message: 'hello',
      );
      const c = DeferredMessage(
        targetKey: (roomId: 'r1', threadId: 't2'),
        message: 'hello',
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString', () {
      const msg = DeferredMessage(
        targetKey: (roomId: 'r1', threadId: 't1'),
        message: 'hello',
      );
      expect(msg.toString(), contains('r1'));
      expect(msg.toString(), contains('t1'));
      expect(msg.toString(), contains('hello'));
    });
  });
}
