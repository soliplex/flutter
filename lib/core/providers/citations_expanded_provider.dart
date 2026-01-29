import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier for tracking citation expand state within a thread.
///
/// Tracks both section-level and individual citation expand state using
/// string keys:
/// - Section: `messageId`
/// - Individual citation: `messageId:citationIndex`
///
/// State is scoped per-thread and autodisposed when the thread is no longer
/// watched.
class CitationsExpandedNotifier extends Notifier<Set<String>> {
  /// Creates a notifier for the given thread ID.
  CitationsExpandedNotifier(this.threadId);

  /// The thread ID this notifier is scoped to.
  final String threadId;

  @override
  Set<String> build() => {};

  /// Toggles expand state for the given [key].
  void toggle(String key) {
    state = state.contains(key) ? ({...state}..remove(key)) : {...state, key};
  }
}

/// Provider for citation expand state, scoped by thread ID.
///
/// **Usage**:
/// ```dart
/// // Watch section expand state (with select to avoid unnecessary rebuilds)
/// final sectionExpanded = ref.watch(
///   citationsExpandedProvider(threadId).select((s) => s.contains(messageId)),
/// );
///
/// // Watch individual citation expand state
/// final citationExpanded = ref.watch(
///   citationsExpandedProvider(threadId)
///       .select((s) => s.contains('$messageId:$index')),
/// );
///
/// // Toggle
/// ref.read(citationsExpandedProvider(threadId).notifier).toggle(messageId);
/// ```
final citationsExpandedProvider =
    NotifierProvider.family<CitationsExpandedNotifier, Set<String>, String>(
  CitationsExpandedNotifier.new,
);
