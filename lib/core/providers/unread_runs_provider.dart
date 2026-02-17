import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/models/thread_key.dart';

/// Tracks which threads have completed runs the user hasn't viewed yet.
///
/// State: `Map<String, Set<String>>` — roomId -> set of unread threadIds.
///
/// Threads are marked unread when a background run completes (non-cancelled),
/// and marked read when the user selects the thread.
class UnreadRunsNotifier extends Notifier<Map<String, Set<String>>> {
  @override
  Map<String, Set<String>> build() => {};

  /// Marks a thread as having an unread completed run.
  void markUnread(ThreadKey key) {
    final current = state[key.roomId] ?? {};
    if (current.contains(key.threadId)) return;
    state = {
      ...state,
      key.roomId: {...current, key.threadId},
    };
  }

  /// Marks a thread as read (user viewed it).
  void markRead(ThreadKey key) {
    final current = state[key.roomId];
    if (current == null || !current.contains(key.threadId)) return;
    final updated = {...current}..remove(key.threadId);
    final newState = {...state};
    if (updated.isNotEmpty) {
      newState[key.roomId] = updated;
    } else {
      newState.remove(key.roomId);
    }
    state = newState;
  }

  /// Whether the given thread has an unread completed run.
  bool isThreadUnread(ThreadKey key) {
    return state[key.roomId]?.contains(key.threadId) ?? false;
  }

  /// Number of threads with unread runs in the given room.
  int unreadCountForRoom(String roomId) {
    return state[roomId]?.length ?? 0;
  }
}

/// Provider for unread run indicators.
final unreadRunsProvider =
    NotifierProvider<UnreadRunsNotifier, Map<String, Set<String>>>(
  UnreadRunsNotifier.new,
);
