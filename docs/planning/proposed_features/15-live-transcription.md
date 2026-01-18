# Feature 15: Live Transcription

## Usage
In a meeting, user hits "Record". App transcribes in real-time on screen. User can tap a paragraph to ask "What did he mean by that?" while recording continues.

## Specification
- **Stream:** WebSocket to Whisper Live or on-device model.
- **Concurrency:** Must handle recording + chatting simultaneously.

## Skeleton Code

```dart
class MeetingAssistant extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SplitView(
      left: TranscriptionStreamList(),
      right: ChatInterface(context: "Use the live transcript on the left..."),
    );
  }
}
```

## Reviews

### Codex Review (Technical)
**Completeness:** Low. Complex concurrency management.
**Feasibility:** Hard.
**Novelty:** High.

### Skeptic Review (Product)
**Critique:** Competes with dedicated apps (Otter, Zoom AI). Might be feature creep for a RAG client unless tightly integrated with internal docs.
