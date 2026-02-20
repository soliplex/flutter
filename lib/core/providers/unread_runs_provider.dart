import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/models/thread_key.dart';

/// Immutable snapshot of which threads have unread completed runs.
class UnreadRuns {
  const UnreadRuns({Map<String, Set<String>> byRoom = const {}})
      : _byRoom = byRoom;

  final Map<String, Set<String>> _byRoom;

  /// Whether the given thread has an unread completed run.
  bool isThreadUnread(ThreadKey key) =>
      _byRoom[key.roomId]?.contains(key.threadId) ?? false;

  /// Number of threads with unread runs in the given room.
  int unreadCountForRoom(String roomId) => _byRoom[roomId]?.length ?? 0;

  bool get isEmpty => _byRoom.isEmpty;
}

/// Tracks which threads have completed runs the user hasn't viewed yet.
///
/// Threads are marked unread when a background run completes (non-cancelled),
/// and marked read when the user selects the thread.
class UnreadRunsNotifier extends Notifier<UnreadRuns> {
  @override
  UnreadRuns build() => const UnreadRuns();

  /// Marks a thread as having an unread completed run.
  void markUnread(ThreadKey key) {
    final current = state._byRoom[key.roomId] ?? {};
    if (current.contains(key.threadId)) return;
    state = UnreadRuns(
      byRoom: {
        ...state._byRoom,
        key.roomId: {...current, key.threadId},
      },
    );
  }

  /// Marks a thread as read (user viewed it).
  void markRead(ThreadKey key) {
    final current = state._byRoom[key.roomId];
    if (current == null || !current.contains(key.threadId)) return;
    final updated = {...current}..remove(key.threadId);
    final newByRoom = {...state._byRoom};
    if (updated.isNotEmpty) {
      newByRoom[key.roomId] = updated;
    } else {
      newByRoom.remove(key.roomId);
    }
    state = UnreadRuns(byRoom: newByRoom);
  }
}

/// Provider for unread run indicators.
final unreadRunsProvider = NotifierProvider<UnreadRunsNotifier, UnreadRuns>(
  UnreadRunsNotifier.new,
);
