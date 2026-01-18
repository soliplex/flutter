# Feature 16: Snippet Library

## Usage
Users can save specific code blocks or text passages to a "Library". These can be tagged and dragged-and-dropped into future chats.

## Specification
- **Storage:** Local DB + Sync.
- **UI:** Draggable chips or sidebar items.

## Skeleton Code

```dart
class Snippet {
  final String content;
  final List<String> tags;
  final DateTime createdAt;
}

class SnippetDraggable extends StatelessWidget {
  final Snippet snippet;
  
  @override
  Widget build(BuildContext context) {
    return Draggable<String>(
      data: snippet.content,
      feedback: Material(child: Text(snippet.content)),
      child: Chip(label: Text(snippet.tags.first)),
    );
  }
}
```

## Reviews

### Codex Review (Technical)
**Completeness:** High.
**Feasibility:** High.
**Novelty:** Medium.

### Skeptic Review (Product)
**Critique:** Good for developers. Replaces "Notes" app.
