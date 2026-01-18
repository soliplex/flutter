# Feature 17: Multi-LLM Arena

## Usage
A "Compare" mode where the same prompt is sent to two models (e.g., GPT-4 vs. Claude 3) side-by-side. User votes on the better answer.

## Specification
- **Backend:** Parallel API calls.
- **UI:** Split view controller.

## Skeleton Code

```dart
class ArenaView extends StatelessWidget {
  final String prompt;
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: ChatWindow(model: 'gpt-4', prompt: prompt)),
        VerticalDivider(),
        Expanded(child: ChatWindow(model: 'claude-3', prompt: prompt)),
      ],
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
**Critique:** Only for power users evaluating models. Normal users don't care, they just want the best answer.
