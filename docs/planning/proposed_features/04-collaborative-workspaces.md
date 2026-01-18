# Feature 04: Collaborative Workspaces

## Usage
Users can invite colleagues to a "Room". Everyone sees the chat stream in real-time. A user can tag another user (`@jaemin`) to ask them to refine a prompt.

## Specification
- **Backend:** WebSocket connection (already likely present for chat stream, needs channel broadcasting).
- **Frontend:** User presence indicators (avatars at top). Typing indicators.
- **CRDTs:** Optional, but might be needed for shared document editing.

## Skeleton Code

```dart
class RoomSocketService {
  final WebSocketChannel channel;

  void joinRoom(String roomId) {
    channel.sink.add(jsonEncode({
      'event': 'join',
      'roomId': roomId,
      'user': currentUser
    }));
  }

  Stream<RoomEvent> get events => channel.stream.map((data) {
    // Parse join/leave/typing/message events
  });
}
```

## Reviews

### Codex Review (Technical)
**Completeness:** Low. Complex permissions model needed.
**Feasibility:** Hard. Real-time state synchronization is buggy. Start with "Shared Read-Only" links first?
**Novelty:** High for RAG. Usually RAG is single-player.

### Skeptic Review (Product)
**Critique:** Who is the target? Teams? If so, this is a game-changer. If it's individual devs, it's useless clutter.
