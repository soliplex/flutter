# Feature 07: Context Pinning & Memory

## Usage
Long-pressing a message or a document snippet offers a "Pin to Context" option. Pinned items are always sent with the prompt, regardless of context window limits, ensuring the AI "remembers" them.

## Specification
- **Backend:** Requires API support to accept a specific "pinned_context" block.
- **UI:** A "Pinned" drawer showing currently active persistent context.

## Skeleton Code

```dart
class ChatState {
  final List<Message> history;
  final List<Message> pinnedMessages;

  // When sending to API
  List<Message> get contextWindow {
    return [...pinnedMessages, ...history.takeLast(N)];
  }
}
```

## Reviews

### Codex Review (Technical)
**Completeness:** Medium. Need to handle token limits—what if user pins too much?
**Feasibility:** High.
**Novelty:** Medium.

### Skeptic Review (Product)
**Critique:** High power-user value. Prevents the "I just told you that 5 minutes ago" frustration.
