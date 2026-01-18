# Feature 02: Offline Sync & Draft Mode

## Usage
Users can interact with the app while offline. They can browse history, view cached documents, and draft new queries. When offline, the "Send" button changes to "Queue". Upon reconnection, queued messages are sent automatically, and background sync updates the history.

## Specification
- **Storage:** `sqlite` (via `drift` or `sqflite`) for local caching of full message history.
- **State Management:** `riverpod` with a connectivity watcher.
- **Sync Logic:** Optimistic UI updates. UUIDs generated on client side to prevent duplication.

## Skeleton Code

```dart
// providers/connectivity_provider.dart
final connectivityProvider = StreamProvider<ConnectivityResult>((ref) {
  return Connectivity().onConnectivityChanged;
});

// services/queue_service.dart
class MessageQueueService {
  final Database db;
  
  Future<void> queueMessage(Message msg) async {
    await db.insertMessage(msg.copyWith(status: MessageStatus.queued));
  }

  Future<void> processQueue() async {
    final queued = await db.getMessages(status: MessageStatus.queued);
    for (var msg in queued) {
      try {
        await api.sendMessage(msg);
        await db.updateMessageStatus(msg.id, MessageStatus.sent);
      } catch (e) {
        // Retry logic
      }
    }
  }
}
```

## Reviews

### Codex Review (Technical)
**Completeness:** Medium. Needs handling of "sync conflicts" if the conversation was updated on another device.
**Feasibility:** High. Standard mobile pattern.
**Novelty:** Low (Expected standard), but critical for UX.

### Skeptic Review (Product)
**Critique:** Essential. Not exciting, but necessary. If we don't have this, we look amateur. Prioritize this over "shiny" features.
