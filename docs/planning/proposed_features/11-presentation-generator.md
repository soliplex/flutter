# Feature 11: Presentation Generator

## Usage
User says "Make a 5-slide deck about this chat". App generates a slide deck using `flutter_deck` or exports to Markdown/PowerPoint.

## Specification
- **Library:** `flutter_deck`.
- **Logic:** LLM outputs JSON structure of slides -> Widget builder renders them.

## Skeleton Code

```dart
// Slide Model
class Slide {
  final String title;
  final List<String> bullets;
  final String? codeSnippet;
}

// Builder
class PresentationViewer extends StatelessWidget {
  final List<Slide> slides;

  @override
  Widget build(BuildContext context) {
    return FlutterDeckApp(
      slides: slides.map((s) => SlideWidget(s)).toList(),
    );
  }
}
```

## Reviews

### Codex Review (Technical)
**Completeness:** Medium. Needs a good "slide layout" engine.
**Feasibility:** Medium.
**Novelty:** High.

### Skeptic Review (Product)
**Critique:** Killer feature for enterprise. "Turn this report into a presentation" is a massive time saver.
