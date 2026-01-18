# Feature Specification: Smart Copy & Action Chips

## 1. Overview
**Smart Copy Chips** are context-aware action buttons attached to specific content blocks (code snippets, tables, or the entire message). They allow users to quickly extract information in the correct format without manual selection struggles.

## 2. Business Case
- **Developer Productivity:** "One-click copy" for code blocks is an industry standard (ChatGPT, Claude, GitHub). Missing it feels broken.
- **Data Portability:** Users often need to move data from the chat to Excel (Table -> CSV) or IDEs.
- **Mobile Usability:** Text selection on mobile is difficult; chips solve this.

## 3. UI/UX Specification
### Code Blocks
- **Visual:** A header bar above the code block containing the language name (e.g., "Dart") on the left and a "Copy" icon/text on the right.
- **Interaction:**
    - **Idle:** "Copy" icon.
    - **Clicked:** Icon changes to a "Checkmark" and text says "Copied!", reverting after 2 seconds.
- **Placement:** Top-right corner of the code container.

### Message Bubbles
- **Visual:** A discrete "Copy" icon in the message footer (action row) alongside generic actions like "Regenerate" or "Feedback".
- **Interaction:** Copies the full raw markdown of the message.

### Tables
- **Visual:** A small chip appearing near the table header on hover/focus: "Copy as CSV" or "Copy as Markdown".

## 4. Technical Implementation

### Code Block Wrapper (Flutter)
We need a custom builder for the Markdown widget to intercept `<pre>`/`<code>` tags.

```dart
class CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final language = element.attributes['class']?.replaceFirst('language-', '') ?? 'text';
    final code = element.textContent;

    return Stack(
      children: [
        // The actual code highlight view
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.black87),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(language, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    CopyButton(content: code),
                  ],
                ),
              ),
              // Code content
              Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(code, style: const TextStyle(fontFamily: 'monospace', color: Colors.white)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

## 5. Codex Review
- **Refinement:** Ensure the clipboard operation is asynchronous and handles permissions on web/mobile if necessary.
- **Edge Case:** Extremely long lines of code need horizontal scrolling without breaking the "Copy" button position.
- **Format:** For tables, converting Markdown Table -> CSV requires a small utility function.

## 6. Skeptic Review
- "This adds too much vertical space for one-line code blocks." -> **Mitigation:** Only show the header for multi-line blocks. For single backticks (`code`), just style them inline without buttons.
