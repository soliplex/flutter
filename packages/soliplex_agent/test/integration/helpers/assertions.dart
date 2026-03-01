import 'package:soliplex_client/soliplex_client.dart';

/// Extracts the last assistant message text, truncated for debug output.
///
/// Truncation at 200 chars keeps test output readable while showing enough
/// context to diagnose failures.
String lastAssistantText(Conversation conversation, {int maxLength = 200}) {
  for (final msg in conversation.messages.reversed) {
    if (msg is TextMessage && msg.user == ChatUser.assistant) {
      return msg.text.length > maxLength
          ? '${msg.text.substring(0, maxLength)}...'
          : msg.text;
    }
  }
  return '(no assistant message found)';
}
