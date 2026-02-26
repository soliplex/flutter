import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/providers/thread_return_stack_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThreadReturnStackNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('starts with empty stack', () {
      final stack = container.read(threadReturnStackProvider);
      expect(stack, isEmpty);
    });

    test('push adds entry to stack', () {
      container.read(threadReturnStackProvider.notifier).push(
            const ThreadReturnEntry(roomId: 'room-1', threadId: 'thread-a'),
          );

      final stack = container.read(threadReturnStackProvider);
      expect(stack, hasLength(1));
      expect(stack.first.threadId, 'thread-a');
    });

    test('pop returns entries in LIFO order', () {
      final notifier = container.read(threadReturnStackProvider.notifier)
        ..push(
          const ThreadReturnEntry(roomId: 'room-1', threadId: 'thread-a'),
        )
        ..push(
          const ThreadReturnEntry(roomId: 'room-1', threadId: 'thread-b'),
        )
        ..push(
          const ThreadReturnEntry(roomId: 'room-1', threadId: 'thread-c'),
        );

      expect(notifier.pop()!.threadId, 'thread-c');
      expect(notifier.pop()!.threadId, 'thread-b');
      expect(notifier.pop()!.threadId, 'thread-a');
    });

    test('pop on empty stack returns null', () {
      final result = container.read(threadReturnStackProvider.notifier).pop();
      expect(result, isNull);
    });

    test('peek returns top entry without removing it', () {
      container.read(threadReturnStackProvider.notifier)
        ..push(
          const ThreadReturnEntry(roomId: 'room-1', threadId: 'thread-a'),
        )
        ..push(
          const ThreadReturnEntry(roomId: 'room-1', threadId: 'thread-b'),
        );

      final peeked = container.read(threadReturnStackProvider.notifier).peek();
      expect(peeked!.threadId, 'thread-b');

      // Stack should still have 2 entries
      final stack = container.read(threadReturnStackProvider);
      expect(stack, hasLength(2));
    });

    test('peek on empty stack returns null', () {
      final result = container.read(threadReturnStackProvider.notifier).peek();
      expect(result, isNull);
    });

    test('clear empties the stack', () {
      container.read(threadReturnStackProvider.notifier)
        ..push(
          const ThreadReturnEntry(roomId: 'room-1', threadId: 'thread-a'),
        )
        ..push(
          const ThreadReturnEntry(roomId: 'room-1', threadId: 'thread-b'),
        )
        ..clear();

      final stack = container.read(threadReturnStackProvider);
      expect(stack, isEmpty);
    });
  });

  group('ThreadReturnEntry', () {
    test('equality', () {
      const a = ThreadReturnEntry(roomId: 'r1', threadId: 't1');
      const b = ThreadReturnEntry(roomId: 'r1', threadId: 't1');
      const c = ThreadReturnEntry(roomId: 'r1', threadId: 't2');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString', () {
      const entry = ThreadReturnEntry(roomId: 'r1', threadId: 't1');
      expect(entry.toString(), contains('r1'));
      expect(entry.toString(), contains('t1'));
    });
  });
}
