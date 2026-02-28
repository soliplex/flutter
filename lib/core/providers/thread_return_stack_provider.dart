import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Entry in the LLM's thread navigation return stack.
///
/// Tracks where the LLM was before switching threads, enabling
/// "switch back" navigation via [ThreadReturnStackNotifier.pop].
@immutable
class ThreadReturnEntry {
  const ThreadReturnEntry({required this.roomId, required this.threadId});

  final String roomId;
  final String threadId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThreadReturnEntry &&
          roomId == other.roomId &&
          threadId == other.threadId;

  @override
  int get hashCode => Object.hash(roomId, threadId);

  @override
  String toString() =>
      'ThreadReturnEntry(roomId: $roomId, threadId: $threadId)';
}

/// LIFO stack tracking the LLM's thread navigation path.
///
/// When the LLM switches threads, the current thread is pushed onto the
/// stack. When the LLM calls switch_thread with "back", the stack is
/// popped to return to the previous thread.
///
/// Persists across room changes so `switch_thread("back")` works after
/// navigating between rooms.
class ThreadReturnStackNotifier extends Notifier<List<ThreadReturnEntry>> {
  @override
  List<ThreadReturnEntry> build() => const [];

  /// Push the current thread onto the return stack.
  void push(ThreadReturnEntry entry) => state = [...state, entry];

  /// Pop the most recent entry (LIFO). Returns null if stack is empty.
  ThreadReturnEntry? pop() {
    if (state.isEmpty) return null;
    final entry = state.last;
    state = state.sublist(0, state.length - 1);
    return entry;
  }

  /// Peek at the top entry without removing it. Returns null if empty.
  ThreadReturnEntry? peek() => state.isEmpty ? null : state.last;

  /// Clear the entire stack.
  void clear() => state = const [];
}

/// Provider for the LLM's thread return stack.
///
/// Used by the `switch_thread` tool to track navigation history and
/// enable "back" navigation.
final threadReturnStackProvider =
    NotifierProvider<ThreadReturnStackNotifier, List<ThreadReturnEntry>>(
  ThreadReturnStackNotifier.new,
);
