# Feature 18: Podcast Generator

## Usage
"Listen to this thread". The app converts the Q&A history into a 2-person scripted audio dialogue (Host & Expert) and plays it back.

## Specification
- **Pipeline:** Chat History -> LLM (Script Generation) -> TTS (Multi-voice).
- **Audio:** Audio player with background music option.

## Skeleton Code

```dart
class PodcastPlayer extends StatefulWidget {
  final List<Message> history;
  
  void generateAndPlay() async {
    final script = await llm.generatePodcastScript(history);
    final audioUrl = await tts.synthesizeConversation(script);
    audioPlayer.play(audioUrl);
  }
}
```

## Reviews

### Codex Review (Technical)
**Completeness:** Medium. Latency is high for generation.
**Feasibility:** Medium.
**Novelty:** Very High (NotebookLM style).

### Skeptic Review (Product)
**Critique:** Viral feature. Very engaging way to consume content.
