# Feature Specification: Thinking Process Visualizer (Thinking Tags)

## 1. Overview
The **Thinking Process Visualizer** allows the chat interface to render the agent's internal chain-of-thought (CoT) separately from the final answer. This is typically delivered within specific tags (e.g., `<thinking>...</thinking>`) or via a specific event stream. The UI should collapse this content by default to keep the interface clean, but allow the user to expand it to inspect the reasoning.

## 2. Business Case
- **Trust & Transparency:** Users trust the AI more when they can see the logic behind a complex answer.
- **Debugging:** Developers can verify if the model is hallucinating or following the correct logical path.
- **Cleanliness:** Keeps the main answer visible immediately, without forcing the user to scroll past pages of reasoning.

## 3. UI/UX Specification
- **Default State:** A collapsed container (accordion style) labeled "Thinking Process" or "Reasoning..." with a subtle background color (e.g., light gray/blue).
- **Expanded State:** When clicked, the container expands to show the raw text or markdown of the thinking process.
- **Animation:** Smooth transition for expanding/collapsing.
- **Streaming:** If the model is currently "thinking" (streaming tokens inside the tags), the container should automatically be present (and possibly expanded or showing a pulsing indicator).
- **Iconography:** A "brain" or "lightbulb" icon next to the header.

## 4. Technical Implementation

### Parsing Logic
We need to parse the incoming stream or message string for `<thinking>` tags.
- **Input:** `String` (message content).
- **Regex:** `/<thinking>(.*?)<\/thinking>/s` (dot-all to capture newlines).
- **Handling:**
    - Extract the content inside the tags.
    - Remove the tags from the "main" display text.
    - Render the extracted content in the `ThinkingWidget`.

### Widget Structure (Flutter)

```dart
class ThinkingWidget extends StatefulWidget {
  final String content;
  final bool isStreaming;

  const ThinkingWidget({
    super.key,
    required this.content,
    this.isStreaming = false,
  });

  @override
  State<ThinkingWidget> createState() => _ThinkingWidgetState();
}

class _ThinkingWidgetState extends State<ThinkingWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ExpansionTile(
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (val) => setState(() => _isExpanded = val),
        leading: const Icon(Icons.psychology_outlined, size: 20),
        title: Text(
          widget.isStreaming ? "Thinking..." : "Reasoning Process",
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: MarkdownBody(data: widget.content),
          ),
        ],
      ),
    );
  }
}
```

## 5. Codex Review (Simulated)
- **Completeness:** The regex approach is brittle if tags are malformed or nested. A better approach is a stream parser state machine.
- **Performance:** `MarkdownBody` inside a list can be expensive if the thinking block is massive. Consider simpler text rendering if formatting isn't needed there.
- **Accessibility:** Ensure the `ExpansionTile` has proper semantic labels.

## 6. Skeptic Review (Simulated)
- "What if the model hallucinates the closing tag? You'll hide the rest of the answer." -> **Mitigation:** Fallback logic. If `<thinking>` opens but never closes, treat the rest of the message as thinking until end-of-stream, or show it all raw.
