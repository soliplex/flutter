import 'package:meta/meta.dart';
import 'package:soliplex_client/src/domain/chat_message.dart';

/// Ephemeral streaming state (application layer, not domain).
///
/// Streaming is operation state that exists only during active streaming.
/// When streaming completes, the text becomes a domain message.
///
/// Use pattern matching for exhaustive handling:
/// ```dart
/// switch (streaming) {
///   case AwaitingText():
///     // Waiting for text to start
///   case TextStreaming(:final messageId, :final text):
///     // Text message is streaming
/// }
/// ```
@immutable
sealed class StreamingState {
  const StreamingState();
}

/// Waiting for text to start streaming.
@immutable
class AwaitingText extends StreamingState {
  /// Creates a not streaming state.
  const AwaitingText();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AwaitingText && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'AwaitingText()';
}

/// Text is currently streaming.
@immutable
class TextStreaming extends StreamingState {
  /// Creates a streaming state with the given [messageId], [user], and
  /// accumulated [text].
  const TextStreaming({
    required this.messageId,
    required this.user,
    required this.text,
  });

  /// The ID of the message being streamed.
  final String messageId;

  /// The user role for this message.
  final ChatUser user;

  /// The text accumulated so far.
  final String text;

  // TODO(cleanup): Consider inlining this in agui_event_processor.dart.
  // This method is only used by one caller (Feature Envy smell). Keeping
  // TextStreaming as pure data would be cleaner.
  /// Creates a copy with the delta appended to text.
  TextStreaming appendDelta(String delta) {
    return TextStreaming(messageId: messageId, user: user, text: text + delta);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextStreaming &&
          runtimeType == other.runtimeType &&
          messageId == other.messageId &&
          user == other.user &&
          text == other.text;

  @override
  int get hashCode => Object.hash(runtimeType, messageId, user, text);

  @override
  String toString() => 'TextStreaming('
      'messageId: $messageId, user: $user, text: ${text.length} chars)';
}
