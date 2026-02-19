import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';

import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/thread_history_cache.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';

/// Provider for source references associated with a user message.
///
/// Returns source references (citations) linked to the given user message ID,
/// or an empty list if none found or if userMessageId is null.
///
/// This provider keys by **user message ID** (not assistant message ID) because
/// citations are correlated at run completion with the user message that
/// triggered the run.
///
/// Sources:
/// 1. Active run's conversation messageStates (if running or completed)
/// 2. Cached thread history messageStates (for historical threads)
final sourceReferencesForUserMessageProvider =
    Provider.family<List<SourceReference>, String?>((ref, userMessageId) {
  if (userMessageId == null) return const [];

  // Try active run first
  final runState = ref.watch(activeRunNotifierProvider);
  if (runState is! IdleState) {
    final state = runState.conversation.messageStates[userMessageId];
    if (state != null) return state.sourceReferences;
  }

  // Fall back to cache
  final roomId = ref.watch(currentRoomIdProvider);
  final threadId = ref.watch(currentThreadIdProvider);
  if (roomId == null || threadId == null) return const [];

  final key = (roomId: roomId, threadId: threadId);
  final cached = ref.watch(threadHistoryCacheProvider)[key];
  return cached?.messageStates[userMessageId]?.sourceReferences ?? const [];
});

/// Provider for the run ID associated with a user message.
///
/// Returns the run ID linked to the given user message ID, or null if not
/// found or if userMessageId is null. Used to construct the feedback endpoint
/// URL when submitting thumbs-up/down feedback.
///
/// Sources:
/// 1. Active run's conversation messageStates (if running or completed)
/// 2. Cached thread history messageStates (for historical threads)
final runIdForUserMessageProvider =
    Provider.family<String?, String?>((ref, userMessageId) {
  if (userMessageId == null) return null;

  // Try active run first
  final runState = ref.watch(activeRunNotifierProvider);
  if (runState is! IdleState) {
    final state = runState.conversation.messageStates[userMessageId];
    if (state != null) return state.runId;
  }

  // Fall back to cache
  final roomId = ref.watch(currentRoomIdProvider);
  final threadId = ref.watch(currentThreadIdProvider);
  if (roomId == null || threadId == null) return null;

  final key = (roomId: roomId, threadId: threadId);
  final cached = ref.watch(threadHistoryCacheProvider)[key];
  return cached?.messageStates[userMessageId]?.runId;
});
