// Both ask_history.dart and haiku_rag_chat.dart define identical Citation
// classes (generated from the same JSON schema via quicktype). We hide the
// ask_history version and use haiku_rag_chat.Citation as the canonical type.
// Conversation.citationsForMessage() handles conversion when reading from
// ask_history state.
export 'ask_history.dart' hide Citation;
export 'haiku_rag_chat.dart';
