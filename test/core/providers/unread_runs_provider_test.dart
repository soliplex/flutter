import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/providers/unread_runs_provider.dart';

void main() {
  group('UnreadRunsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('initial state', () {
      test('starts empty', () {
        expect(container.read(unreadRunsProvider), isEmpty);
      });
    });

    group('markUnread', () {
      test('adds thread to unread set for room', () {
        container
            .read(unreadRunsProvider.notifier)
            .markUnread(const (roomId: 'room-1', threadId: 'thread-1'));

        final state = container.read(unreadRunsProvider);
        expect(state['room-1'], contains('thread-1'));
      });

      test('adds multiple threads for same room', () {
        final notifier = container.read(unreadRunsProvider.notifier)
          ..markUnread(const (roomId: 'room-1', threadId: 'thread-1'))
          ..markUnread(const (roomId: 'room-1', threadId: 'thread-2'));

        expect(notifier.unreadCountForRoom('room-1'), 2);
      });

      test('adds threads across different rooms', () {
        container.read(unreadRunsProvider.notifier)
          ..markUnread(const (roomId: 'room-1', threadId: 'thread-1'))
          ..markUnread(const (roomId: 'room-2', threadId: 'thread-2'));

        final state = container.read(unreadRunsProvider);
        expect(state['room-1'], contains('thread-1'));
        expect(state['room-2'], contains('thread-2'));
      });

      test('is idempotent for same thread', () {
        container.read(unreadRunsProvider.notifier)
          ..markUnread(const (roomId: 'room-1', threadId: 'thread-1'))
          ..markUnread(const (roomId: 'room-1', threadId: 'thread-1'));

        expect(
          container.read(unreadRunsProvider.notifier).unreadCountForRoom(
                'room-1',
              ),
          1,
        );
      });
    });

    group('markRead', () {
      test('removes thread from unread set', () {
        container.read(unreadRunsProvider.notifier)
          ..markUnread(const (roomId: 'room-1', threadId: 'thread-1'))
          ..markUnread(const (roomId: 'room-1', threadId: 'thread-2'))
          ..markRead(const (roomId: 'room-1', threadId: 'thread-1'));

        final state = container.read(unreadRunsProvider);
        expect(state['room-1'], isNot(contains('thread-1')));
        expect(state['room-1'], contains('thread-2'));
      });

      test('removes room key when last thread is marked read', () {
        container.read(unreadRunsProvider.notifier)
          ..markUnread(const (roomId: 'room-1', threadId: 'thread-1'))
          ..markRead(const (roomId: 'room-1', threadId: 'thread-1'));

        final state = container.read(unreadRunsProvider);
        expect(state.containsKey('room-1'), isFalse);
      });

      test('is no-op for non-existent room', () {
        container
            .read(unreadRunsProvider.notifier)
            .markRead(const (roomId: 'room-1', threadId: 'thread-1'));

        expect(container.read(unreadRunsProvider), isEmpty);
      });

      test('is no-op for non-existent thread in existing room', () {
        container.read(unreadRunsProvider.notifier)
          ..markUnread(const (roomId: 'room-1', threadId: 'thread-1'))
          ..markRead(const (roomId: 'room-1', threadId: 'thread-2'));

        final state = container.read(unreadRunsProvider);
        expect(state['room-1'], contains('thread-1'));
      });

      test('does not affect other rooms', () {
        container.read(unreadRunsProvider.notifier)
          ..markUnread(const (roomId: 'room-1', threadId: 'thread-1'))
          ..markUnread(const (roomId: 'room-2', threadId: 'thread-2'))
          ..markRead(const (roomId: 'room-1', threadId: 'thread-1'));

        final state = container.read(unreadRunsProvider);
        expect(state.containsKey('room-1'), isFalse);
        expect(state['room-2'], contains('thread-2'));
      });
    });

    group('isThreadUnread', () {
      test('returns true for unread thread', () {
        container
            .read(unreadRunsProvider.notifier)
            .markUnread(const (roomId: 'room-1', threadId: 'thread-1'));

        expect(
          container
              .read(unreadRunsProvider.notifier)
              .isThreadUnread(const (roomId: 'room-1', threadId: 'thread-1')),
          isTrue,
        );
      });

      test('returns false for read thread', () {
        container.read(unreadRunsProvider.notifier)
          ..markUnread(const (roomId: 'room-1', threadId: 'thread-1'))
          ..markRead(const (roomId: 'room-1', threadId: 'thread-1'));

        expect(
          container
              .read(unreadRunsProvider.notifier)
              .isThreadUnread(const (roomId: 'room-1', threadId: 'thread-1')),
          isFalse,
        );
      });

      test('returns false for unknown room', () {
        expect(
          container
              .read(unreadRunsProvider.notifier)
              .isThreadUnread(const (roomId: 'room-1', threadId: 'thread-1')),
          isFalse,
        );
      });

      test('returns false for unknown thread in known room', () {
        container
            .read(unreadRunsProvider.notifier)
            .markUnread(const (roomId: 'room-1', threadId: 'thread-1'));

        expect(
          container
              .read(unreadRunsProvider.notifier)
              .isThreadUnread(const (roomId: 'room-1', threadId: 'thread-2')),
          isFalse,
        );
      });
    });

    group('unreadCountForRoom', () {
      test('returns 0 for unknown room', () {
        expect(
          container
              .read(unreadRunsProvider.notifier)
              .unreadCountForRoom('room-1'),
          0,
        );
      });

      test('returns correct count', () {
        container.read(unreadRunsProvider.notifier)
          ..markUnread(const (roomId: 'room-1', threadId: 'thread-1'))
          ..markUnread(const (roomId: 'room-1', threadId: 'thread-2'))
          ..markUnread(const (roomId: 'room-1', threadId: 'thread-3'));

        expect(
          container
              .read(unreadRunsProvider.notifier)
              .unreadCountForRoom('room-1'),
          3,
        );
      });

      test('decreases after markRead', () {
        container.read(unreadRunsProvider.notifier)
          ..markUnread(const (roomId: 'room-1', threadId: 'thread-1'))
          ..markUnread(const (roomId: 'room-1', threadId: 'thread-2'))
          ..markRead(const (roomId: 'room-1', threadId: 'thread-1'));

        expect(
          container
              .read(unreadRunsProvider.notifier)
              .unreadCountForRoom('room-1'),
          1,
        );
      });

      test('returns 0 after all threads marked read', () {
        container.read(unreadRunsProvider.notifier)
          ..markUnread(const (roomId: 'room-1', threadId: 'thread-1'))
          ..markRead(const (roomId: 'room-1', threadId: 'thread-1'));

        expect(
          container
              .read(unreadRunsProvider.notifier)
              .unreadCountForRoom('room-1'),
          0,
        );
      });
    });
  });
}
