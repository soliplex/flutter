import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';

import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/thread_history_cache.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';

/// Provider for citations associated with a specific message.
///
/// Returns citations linked to the given message ID, or an empty list if none.
///
/// Sources citations from:
/// 1. Active run's conversation (if running or completed)
/// 2. Cached thread history (for historical threads without active runs)
final citationsForMessageProvider =
    Provider.family<List<Citation>, String>((ref, messageId) {
  final runState = ref.watch(activeRunNotifierProvider);

  // If there's an active/completed run, use its conversation's aguiState
  if (runState is! IdleState) {
    final citations = runState.conversation.citationsForMessage(messageId);
    if (citations.isNotEmpty) {
      return citations;
    }
    // Active run has no citations for this message - fall through to cache
  }

  // Fall back to cached aguiState for historical threads
  final thread = ref.watch(currentThreadProvider);
  if (thread == null) return [];

  final cacheState = ref.watch(threadHistoryCacheProvider);
  final cachedHistory = cacheState[thread.id];
  if (cachedHistory == null) return [];

  // Build a temporary conversation with cached data to use citationsForMessage
  final conversation = Conversation(
    threadId: thread.id,
    messages: cachedHistory.messages,
    aguiState: cachedHistory.aguiState,
  );

  return conversation.citationsForMessage(messageId);
});
