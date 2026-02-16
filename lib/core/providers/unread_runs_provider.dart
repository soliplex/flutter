import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  void markUnread(String roomId, String threadId) {
    final current = state[roomId] ?? {};
    if (current.contains(threadId)) return;
    state = {
      ...state,
      roomId: {...current, threadId},
    };
  }

  /// Marks a thread as read (user viewed it).
  void markRead(String roomId, String threadId) {
    final current = state[roomId];
    if (current == null || !current.contains(threadId)) return;
    final updated = {...current}..remove(threadId);
    final newState = {...state};
    if (updated.isNotEmpty) {
      newState[roomId] = updated;
    } else {
      newState.remove(roomId);
    }
    state = newState;
  }

  /// Whether the given thread has an unread completed run.
  bool isThreadUnread(String roomId, String threadId) {
    return state[roomId]?.contains(threadId) ?? false;
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
