# flutter_md Audit Report (Gemini)

**Package:** flutter_md v0.0.8
**Publisher:** plugfox.dev (Mike Matiunin)
**Repository:** <https://github.com/DoctorinaAI/md>
**License:** MIT
**Auditor:** Gemini 3 Pro Preview
**Date:** 2026-02-10
**Context:** Evaluating for production use in Soliplex AI chat application

---

## Architecture

`flutter_md` diverges significantly from the standard `flutter_markdown` approach.
While `flutter_markdown` parses Markdown into an AST and converts that AST into a
tree of standard Flutter Widgets (`Column`, `RichText`, `Wrap`), `flutter_md` parses
text into a custom node structure and **paints it directly to a Canvas** using a
custom `RenderObject`.

**Pipeline:**

1. **Input:** Raw Markdown String.
2. **Parser:** `MarkdownDecoder` (Regex-based) converts String to `Markdown`
   object (List of `MD$Block`).
3. **Widget:** `MarkdownWidget` creates `MarkdownRenderObject`.
4. **Layout/Paint:** `MarkdownPainter` iterates through blocks, assigning each
   a `BlockPainter` (e.g., `BlockPainter$Paragraph`).
5. **Rasterization:** `TextPainter` instances paint text directly to the canvas;
   lines/decorations are drawn using `canvas.draw*`.

**Architecture Diagram:**

```text
Raw String
    |
    v (parser.dart)
Markdown Object
    |-- Contains: List<MD$Block>
    |
    v (widget.dart)
MarkdownWidget
    |
    v (render.dart)
MarkdownRenderObject
    |
    v (render.dart)
MarkdownPainter
    |-- Delegates to: BlockPainters
    |
    v
Canvas
```

---

## Source File Walkthrough

### `lib/src/parser.dart`

**Purpose:** Converts strings to `MD$Block` nodes.

**Patterns:** Uses `RegExp` for block identification and manual byte
scanning/bitmasking for inline parsing.

**Concerns:**

- **Regex Fragility:** Uses regex for block parsing (Line 30-36). This is
  often less robust than a state-machine parser like commonmark.js or the
  official `package:markdown`.
- **Manual Scanning:** `_parseInlineSpans` (Line 296) manually iterates byte
  codes. While fast, edge cases in complex nested markdown (common in AI code
  generation) may break it.
- **TODOs:** Contains comments like `// TODO(plugfox): Implement indentation
  for quotes` (Line 100), indicating incomplete logic.

### `lib/src/nodes.dart`

**Purpose:** Data models for the Markdown tree.

**Patterns:** Uses Dart 3 `sealed class` for Blocks and `extension type` for
Styles (Bitmasks).

**Key Classes:** `MD$Block`, `MD$Paragraph`, `MD$Code`, `MD$Style`.

**Observation:** Very memory efficient. `MD$Style` uses integer bitmasking
(Line 11) instead of object allocation, contributing to the performance claims.
`MD$Image` is notably commented out (Line 603).

### `lib/src/render.dart`

**Purpose:** The core rendering engine.

**Patterns:** Custom `RenderBox` implementation. Delegates painting to specific
`BlockPainter` classes.

**Key Classes:** `MarkdownRenderObject`, `MarkdownPainter`, `BlockPainter$*`.

**Concerns:**

- **Accessibility:** `MarkdownRenderObject` extends `RenderBox` but **does not**
  override `describeSemanticsConfiguration` or assemble a semantics tree. **This
  is a critical accessibility failure.** Screen readers will likely not see this
  content.
- **Hit Testing:** Implements manual binary search for hit testing (Line 196)
  to detect link taps.
- **Selection:** Does not implement `Selectable` or `SelectionRegistrar` logic.
  `SelectionArea` wrapping in Soliplex will **not work** with this package out of
  the box.

### `lib/src/theme.dart`

**Purpose:** Theming configuration.

**Patterns:** `InheritedWidget` and `ThemeExtension`.

**Observation:** Well-structured. Allows passing a `builder` to override how
blocks are painted, but requires returning a `BlockPainter` (low-level), not a
Widget.

---

## Scoring Table (1-10)

| # | Requirement | Score | Justification |
|---|---|:---:|---|
| 1 | **Native Widget Embedding** | **1** | Critical fail. The package paints to a canvas. You cannot embed a Flutter Button, Card, or custom Widget inside the markdown flow without rewriting the rendering logic to use `WidgetSpan` (which is difficult in this architecture). |
| 2 | **Interactive Elements** | **3** | Basic link tapping is supported via manual hit-testing. Complex interactions (forms, copy buttons in code blocks) are extremely difficult to implement. |
| 3 | **Extensibility** | **3** | You can define custom `BlockPainters`, but you must write low-level `Canvas` and `TextPainter` code. You cannot simply swap a tag for a Widget as in `flutter_markdown`. |
| 4 | **AI Streaming** | **7** | Performance is high, so frequent rebuilds are cheap. However, `Markdown.fromString` (Line 27, `markdown.dart`) parses the entire string every frame. It lacks a delta/incremental parser. |
| 5 | **Architecture & Design** | **8** | Modern Dart 3 usage, clean separation of data/parsing/rendering. Bitmasking for styles is clever for performance. |
| 6 | **Code Quality** | **7** | Code is clean, but contains `TODO`s regarding indentation and list parsing in tests. Manual byte scanning is risky for maintainability. |
| 7 | **API Compatibility** | **1** | Zero compatibility. Requires a full rewrite of your chat bubble implementation. |
| 8 | **Performance** | **9** | Claims of 120FPS are plausible. Bypassing the Widget tree overhead for massive text blocks is a valid optimization strategy. |
| 9 | **Feature Completeness** | **4** | No images (commented out). Tables are new and basic. LaTeX is not supported. GFM compliance is partial. |
| 10 | **Accessibility** | **0** | Blocker. No Semantics tree. Screen readers (TalkBack/VoiceOver) will treat chat bubbles as empty space or a generic image. |

---

## Critical Issues

1. **Accessibility (Blocker):** The `MarkdownRenderObject` does not expose
   semantic nodes. For a production app, this violates accessibility standards.
   Users relying on screen readers will not be able to read chat messages.

2. **No Image Support:** The `MD$Image` class is commented out in `nodes.dart`,
   and the README explicitly states "Images currently not displayed!"

3. **Broken Text Selection:** Soliplex uses `SelectionArea`. Since `flutter_md`
   paints text manually and does not hook into the `SelectionRegistrar`, users
   cannot natively select/copy text from chat bubbles.

4. **No Widget Embedding:** Soliplex's "Custom CodeBlockBuilder" likely returns
   a Widget (e.g., a container with a copy button and syntax highlighting).
   `flutter_md` only supports painting. You would lose your custom code block UI.

5. **Hard Dependency on System Fonts:** The renderer manually manages
   `TextPainter` lifecycles. While it attempts to handle system font changes
   (v0.0.8 changelog), this manual management is error-prone compared to
   standard Flutter Text widgets.

---

## Migration Path

To migrate from `flutter_markdown` to `flutter_md`, Soliplex would need to:

1. **Rewrite Chat Bubbles:** Replace `MarkdownBody` with `MarkdownWidget`.
2. **Re-implement Syntax Highlighting:** You cannot use standard syntax
   highlighting widgets. You would need to write a custom `BlockPainter` that
   parses code, tokenizes it, and generates `TextSpan`s with specific colors
   manually.
3. **Lose UI Features:** Remove copy buttons from code blocks, remove any
   interactive widgets embedded in markdown, and disable `SelectionArea`
   support for chat content.
4. **Implement Accessibility:** You would need to fork the package and
   implement `describeSemanticsConfiguration` and `assembleSemanticsNode`
   manually in `RenderBox`.

---

## Verdict: NO-GO

**Recommendation:** Do not use `flutter_md` for Soliplex in its current state.

**Reasoning:**
While the performance claims are attractive, the trade-offs are too severe for a
production chat application. The lack of **Accessibility** and **Text Selection**
are immediate disqualifiers. Furthermore, the inability to render **Images** and
the difficulty of embedding custom widgets (like your Code Block UI) would result
in a regression of features compared to your current setup.

**Alternative:**
If performance is the primary concern with `flutter_markdown`, consider:

1. Running the `markdown` package's parsing in an `Isolate` (compute) to avoid
   blocking the UI thread during streaming.
2. Implementing a custom `SyntaxHighlighter` that is more efficient.
3. Using `const` constructors where possible in your builders.

Stick with `flutter_markdown` for now.
