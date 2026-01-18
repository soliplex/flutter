# Feature Specification: Interactive Citations

## 1. Overview
**Interactive Citations** link assertions in the agent's text to their source documents. When the agent generates a response based on RAG (Retrieval-Augmented Generation), it appends citation markers (e.g., `[1]`, `[2]`). These markers should be clickable, triggering a UI action to view the source.

## 2. Business Case
- **Veracity:** Critical for "Soliplex" (Enterprise RAG) to prove answers aren't hallucinations.
- **Compliance:** In legal/finance, you cannot provide an answer without a direct reference.
- **Navigation:** Acts as a bridge between the "Synthesis" (Chat) and the "Source of Truth" (Documents).

## 3. UI/UX Specification
- **Visual:**
    - Inline markers: Small, superscript-style chips `[1]` with a distinct color (e.g., primary blue).
    - Hover state: Shows a small tooltip with the document title.
- **Interaction:**
    - **Click:** Opens the **Source Inspector** (see Feature #5) or scrolls to a "Sources" footer.
- **Sources Footer:** At the bottom of the message, a list of used sources:
    - `[1] Employee Handbook 2024.pdf (Page 12)`
    - `[2] Q3 Financials.xlsx (Row 45)`

## 4. Technical Implementation

### Data Structure
The backend (AG-UI) likely sends citations in a separate metadata field or embedded in the text.
Assuming embedded text `[1]`, we need a list of `Source` objects to map the ID.

```dart
class Citation {
  final int id;
  final String documentTitle;
  final String uri;
  final List<double>? bbox; // For PDF highlighting
  final String snippet;
}
```

### Rendering (Custom Markdown Syntax)
We need to parse `[n]` and replace it with a widget span.

```dart
// Regex for citation: \[(\d+)\]
// Map this to a WidgetSpan in the RichText
InlineSpan buildCitationSpan(String text, Map<int, Citation> sources) {
  final match = RegExp(r'^\[(\d+)\]$').firstMatch(text);
  final id = int.parse(match!.group(1)!);
  final source = sources[id];

  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: InkWell(
      onTap: () => openSourceViewer(source),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Text(
          '$id',
          style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
        ),
      ),
    ),
  );
}
```

## 5. Codex Review
- **Completeness:** Handle cases where `[1]` appears in code blocks (should not be parsed as citation). The Markdown parser must be context-aware.
- **State:** The `sources` map needs to be synchronized with the message stream.

## 6. Skeptic Review
- "Users click these by accident on mobile." -> **Mitigation:** Ensure sufficient touch target size (44px min recommended, but for inline text 24px is acceptable if padded).
- "What if the source document is deleted?" -> **Mitigation:** Handle 404s gracefully in the viewer.
