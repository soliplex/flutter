import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier for tracking which citation sections are expanded.
///
/// Maintains a set of expanded message IDs. Expand state persists across
/// widget rebuilds (e.g., during scrolling or state updates).
class CitationsExpandedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  /// Returns whether the citation section for [messageId] is expanded.
  bool isExpanded(String messageId) => state.contains(messageId);

  /// Toggles the expand state for [messageId].
  void toggle(String messageId) {
    if (state.contains(messageId)) {
      state = {...state}..remove(messageId);
    } else {
      state = {...state, messageId};
    }
  }
}

/// Provider for tracking which citation sections are expanded.
///
/// Use [CitationsExpandedNotifier.isExpanded] to check expand state,
/// and [CitationsExpandedNotifier.toggle] to toggle it.
final citationsExpandedProvider =
    NotifierProvider<CitationsExpandedNotifier, Set<String>>(
  CitationsExpandedNotifier.new,
);
