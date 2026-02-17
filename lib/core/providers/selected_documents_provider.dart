import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';

import 'package:soliplex_frontend/core/models/thread_key.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';

/// Notifier that stores document selections per thread.
///
/// Selections persist in memory across runs within the same thread.
/// Each thread maintains its own independent selection state.
///
/// **Usage**:
/// ```dart
/// // Update selection for current thread
/// ref.read(selectedDocumentsNotifierProvider.notifier)
///     .setForThread(roomId, threadId, selectedDocs);
///
/// // Get selection for current thread (via convenience provider)
/// final docs = ref.watch(currentSelectedDocumentsProvider);
/// ```
class SelectedDocumentsNotifier
    extends Notifier<Map<ThreadKey, Set<RagDocument>>> {
  @override
  Map<ThreadKey, Set<RagDocument>> build() => {};

  /// Gets the selection for a specific thread.
  ///
  /// Returns an empty set if no documents are selected for the thread.
  Set<RagDocument> getForThread(String roomId, String threadId) {
    return state[(roomId: roomId, threadId: threadId)] ?? {};
  }

  /// Updates the selection for a specific thread.
  ///
  /// Replaces any existing selection for the thread.
  void setForThread(
    String roomId,
    String threadId,
    Set<RagDocument> documents,
  ) {
    final key = (roomId: roomId, threadId: threadId);
    state = {...state, key: documents};
  }

  /// Clears the selection for a specific thread.
  void clearForThread(String roomId, String threadId) {
    final key = (roomId: roomId, threadId: threadId);
    state = Map.fromEntries(
      state.entries.where((e) => e.key != key),
    );
  }

  /// Clears all selections for a specific room.
  ///
  /// Useful when a room is deleted or the user leaves a room.
  void clearForRoom(String roomId) {
    state = Map.fromEntries(
      state.entries.where((e) => e.key.roomId != roomId),
    );
  }
}

/// Provider for document selection state storage.
///
/// Use [currentSelectedDocumentsProvider] for read access to the current
/// thread's selection, and the notifier's `setForThread` method for updates.
final selectedDocumentsNotifierProvider = NotifierProvider<
    SelectedDocumentsNotifier, Map<ThreadKey, Set<RagDocument>>>(
  SelectedDocumentsNotifier.new,
);

/// Provider for the current thread's document selection.
///
/// Returns an empty set if no thread is selected or no documents are selected.
/// Automatically updates when the current thread changes.
///
/// **Usage**:
/// ```dart
/// // In a widget
/// final selectedDocs = ref.watch(currentSelectedDocumentsProvider);
/// ```
final currentSelectedDocumentsProvider = Provider<Set<RagDocument>>((ref) {
  final roomId = ref.watch(currentRoomIdProvider);
  final threadId = ref.watch(currentThreadIdProvider);

  if (roomId == null || threadId == null) {
    return {};
  }

  final selections = ref.watch(selectedDocumentsNotifierProvider);
  return selections[(roomId: roomId, threadId: threadId)] ?? {};
});
