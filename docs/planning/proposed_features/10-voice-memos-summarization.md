# Feature 10: Voice Memos to Text

## Usage
User records a 5-minute rambly voice note. Soliplex transcribes it and auto-formats it into a clean bulleted list or a structured bug report.

## Specification
- **Audio:** `flutter_sound` or `record`.
- **Pipeline:** Upload -> Transcribe (Whisper) -> Summarize (LLM).

## Skeleton Code

```dart
class AudioRecorderWidget extends StatelessWidget {
  Future<void> stopAndSend() async {
    final path = await recorder.stop();
    ref.read(chatProvider).uploadAudioForTranscription(path);
  }
}
```

## Reviews

### Codex Review (Technical)
**Completeness:** High.
**Feasibility:** High.
**Novelty:** Low (Otter.ai, etc do this), but integrated into the chat workflow is nice.

### Skeptic Review (Product)
**Critique:** "Rubber duck debugging" on steroids. Great for mobile users who hate typing long context.
