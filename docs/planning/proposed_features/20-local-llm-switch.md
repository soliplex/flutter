# Feature 20: Local LLM Switch

## Usage
A toggle to switch backend to "On-Device (Gemma/Llama)". Uses MediaPipe/TFLite to run inference locally on the phone/laptop without internet.

## Specification
- **Library:** `mediapipe_genai` or `llama.rn`.
- **Performance:** Needs high-end device (M1/M2/M3 or specialized NPU).

## Skeleton Code

```dart
class LLMService {
  final bool useLocal;
  
  Stream<String> generate(String prompt) {
    if (useLocal) {
      return localEngine.generateStream(prompt);
    } else {
      return api.generateStream(prompt);
    }
  }
}
```

## Reviews

### Codex Review (Technical)
**Completeness:** Medium. Model weight download management is heavy (2GB+).
**Feasibility:** Low/Medium (Device dependent).
**Novelty:** High.

### Skeptic Review (Product)
**Critique:** The "Privacy" selling point is huge. "Your data never leaves this device."
