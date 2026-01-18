# Feature 06: Custom Personas

## Usage
Users can create "Assistants" with pre-defined system prompts (e.g., "Code Reviewer", "Legal summarizer", "ELI5"). These appear in a sidebar or dropdown. Switching personas changes the system prompt for the current or new thread.

## Specification
- **Storage:** Local database or backend profile sync.
- **UI:** A "Persona Editor" with a template gallery.

## Skeleton Code

```dart
class Persona {
  final String id;
  final String name;
  final String systemPrompt;
  final IconData icon;
}

// In ChatProvider
void switchPersona(Persona newPersona) {
  state = state.copyWith(
    currentPersona: newPersona,
    messages: [/* system message */, ...existingMessages]
  );
}
```

## Reviews

### Codex Review (Technical)
**Completeness:** High.
**Feasibility:** High. Trivial state management change.
**Novelty:** Low (Standard LLM feature), but users expect it.

### Skeptic Review (Product)
**Critique:** "Do users actually create these?" Most users stick to default. Make sure we ship with 5-10 *really good* built-in ones so they see the value immediately.
