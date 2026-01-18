# Feature 08: Deep Research Mode

## Usage
A toggle for "Deep Mode". When asked a question, the UI shows a multi-step progress bar: "Searching Web...", "Reading 5 articles...", "Synthesizing...", "Drafting Answer". This allows for slower but higher quality responses.

## Specification
- **Backend:** Long-running job (async).
- **Frontend:** Polling or WebSocket events to update the "Thinking" UI steps.

## Skeleton Code

```dart
enum ResearchStep { searching, reading, reasoning, writing }

class ResearchProgressWidget extends StatelessWidget {
  final ResearchStep currentStep;
  
  @override
  Widget build(BuildContext context) {
    return Stepper(
      currentStep: currentStep.index,
      steps: [
        Step(title: Text("Searching sources"), content: LinearProgressIndicator()),
        Step(title: Text("Analyzing content"), content: LinearProgressIndicator()),
        // ...
      ],
    );
  }
}
```

## Reviews

### Codex Review (Technical)
**Completeness:** High.
**Feasibility:** Backend-heavy. Frontend is just visualization.
**Novelty:** High (like o1 or Perplexity Pro).

### Skeptic Review (Product)
**Critique:** People hate waiting, *unless* you show them what's happening. The visualization is key here. If it just spins for 60 seconds, they will quit.
