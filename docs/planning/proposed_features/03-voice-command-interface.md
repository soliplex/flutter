# Feature 03: Hands-Free Voice Interface

## Usage
A "Headphones" mode where the user can converse with Soliplex purely via audio. The screen dims (to save battery). The app listens for a wake word or uses VAD (Voice Activity Detection) to turn taking.

## Specification
- **STT (Speech-to-Text):** `speech_to_text` (on-device) or Whisper API.
- **TTS (Text-to-Speech):** `flutter_tts` or ElevenLabs API.
- **UI:** Visualizer waveform when active.

## Skeleton Code

```dart
class VoiceModeController extends StateNotifier<VoiceState> {
  final SpeechToText _speech;
  final FlutterTts _tts;

  Future<void> listen() async {
    state = VoiceState.listening;
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          state = VoiceState.processing;
          _submitQuery(result.recognizedWords);
        }
      },
    );
  }

  Future<void> speak(String text) async {
    state = VoiceState.speaking;
    await _tts.speak(text);
    await _tts.awaitSpeakCompletion(true);
    listen(); // Turn-taking loop
  }
}
```

## Reviews

### Codex Review (Technical)
**Completeness:** Medium. Needs VAD handling to avoid cutting off user mid-sentence.
**Feasibility:** Medium. Latency is the killer here. Needs streaming API responses to start TTS immediately.
**Novelty:** Medium.

### Skeptic Review (Product)
**Critique:** Good for accessibility and "on the go". Ensure the voice doesn't sound robotic, or people won't use it for long sessions.
