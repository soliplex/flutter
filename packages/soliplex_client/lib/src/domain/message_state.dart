import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'package:soliplex_client/src/domain/source_reference.dart';

/// State associated with a user message and its response.
///
/// Keyed by user message ID, this captures the source references (citations)
/// that were retrieved during the assistant's response to that message.
@immutable
class MessageState {
  /// Creates a message state.
  MessageState({
    required this.userMessageId,
    required List<SourceReference> sourceReferences,
  }) : sourceReferences = List.unmodifiable(sourceReferences);

  /// The ID of the user message this state is associated with.
  final String userMessageId;

  /// Source references (citations) retrieved for the assistant's response.
  final List<SourceReference> sourceReferences;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MessageState) return false;
    const listEquals = ListEquality<SourceReference>();
    return userMessageId == other.userMessageId &&
        listEquals.equals(sourceReferences, other.sourceReferences);
  }

  @override
  int get hashCode => Object.hash(
        userMessageId,
        const ListEquality<SourceReference>().hash(sourceReferences),
      );

  @override
  String toString() => 'MessageState('
      'userMessageId: $userMessageId, '
      'sourceReferences: ${sourceReferences.length})';
}
