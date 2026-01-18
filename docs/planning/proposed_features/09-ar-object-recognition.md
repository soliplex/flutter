# Feature 09: AR Object Recognition

## Usage
User opens the camera, points it at a server rack, a document, or a component. App snaps a photo, analyzes it, and the user can chat about it ("What model server is this?" or "Summarize this page").

## Specification
- **Input:** Camera stream / Image Picker.
- **Vision Model:** GPT-4o Vision or similar backend endpoint.

## Skeleton Code

```dart
import 'package:camera/camera.dart';

Future<void> analyzeImage(XFile image) async {
  final bytes = await image.readAsBytes();
  final base64Image = base64Encode(bytes);
  
  // Add to chat as image attachment
  ref.read(chatProvider.notifier).sendMessage(
    text: "What is this?",
    attachments: [Attachment(type: 'image', data: base64Image)]
  );
}
```

## Reviews

### Codex Review (Technical)
**Completeness:** High.
**Feasibility:** High (Standard multimodal API).
**Novelty:** Medium.

### Skeptic Review (Product)
**Critique:** Mobile-first feature. Very compelling for field work (IT technicians, etc.).
