# Audit Report: `flutter_markdown_plus` v1.0.7

**Auditor:** Gemini 3 Pro Preview
**Date:** 2026-02-10
**Package:** [flutter_markdown_plus](https://pub.dev/packages/flutter_markdown_plus) v1.0.7
**Context:** Soliplex AI chat application migration evaluation

---

## Executive Summary

`flutter_markdown_plus` appears to be a direct maintenance fork of the original
`flutter_markdown` package. For Soliplex, this is a **low-risk migration** regarding API
compatibility, but it carries **medium-to-high risk** regarding performance for long,
streaming AI responses due to its full-rebuild architecture.

**Weighted Score: 7.3 / 10**

---

## Detailed Axis Audit

### 1. Native Widget Embedding -- 8/10

**Reference:** `lib/src/widget.dart:363`, `lib/src/builder.dart:257`

The package supports a `builders` map which allows you to define custom
`MarkdownElementBuilder`s for specific Markdown tags. While you cannot embed a standard
Flutter widget directly into the raw markdown string (e.g., `<MyWidget/>`), you can hijack
HTML tags (like `sub`) or define custom syntax parsers to map to standard Flutter widgets.

**Soliplex Impact:** Your existing `CodeBlockBuilder` will continue to work exactly as it
does now.

### 2. Interactive Elements -- 7/10

**Reference:** `lib/src/widget.dart:341`, `lib/src/builder.dart:766`

Link handling is robust via `onTapLink`. Images are wrapped in `GestureDetector` if link
handlers are present. However, arbitrary interactive elements (like a "Copy" button inside a
code block) rely entirely on the implementation of your custom builders. The base package
primarily handles static text interaction (links).

**Soliplex Impact:** Supports `onTapLink` for handling citations/references natively.

### 3. Extensibility -- 9/10

**Reference:** `lib/src/widget.dart:354-368`

Excellent extensibility. You can inject:

1. `blockSyntaxes` / `inlineSyntaxes` (to parse new Markdown patterns).
2. `builders` (to render custom Widgets).
3. `paddingBuilders` (to adjust spacing).

**Soliplex Impact:** Highly compatible with your custom Syntax Highlighting builder.

### 4. AI Streaming (Incremental Rendering) -- 4/10

**Reference:** `lib/src/widget.dart:452-463`

**Weak point.** The `didUpdateWidget` method calls `_parseMarkdown()`. This function:

1. Splits the *entire* string into lines.
2. Reparses the *entire* AST.
3. Rebuilds the *entire* widget list.

**Soliplex Impact:** As the LLM response grows (e.g., >1000 tokens), the UI thread may jank
on every token update because the parsing complexity is O(N) relative to message length,
occurring roughly 20-50 times per second during generation.

### 5. Architecture & Design -- 8/10

**Reference:** `lib/src/builder.dart:109`

Implements the Visitor pattern (`md.NodeVisitor`). The separation between `MarkdownWidget`
(configuration), `MarkdownBuilder` (logic), and `MarkdownStyleSheet` (theming) is clean and
established.

**Soliplex Impact:** Familiar architecture makes maintenance easy for your team.

### 6. Code Quality -- 8/10

**Reference:** `lib/src/style_sheet.dart:308`, `lib/src/_functions_web.dart:1`

Uses modern Dart features (e.g., `dart:js_interop`). Type safety is strong. Deprecated
members (like `textScaleFactor`) are handled correctly with fallbacks to `textScaler`.

**Soliplex Impact:** Low risk of internal runtime exceptions.

### 7. API Compatibility -- 10/10

**Reference:** `lib/src/widget.dart:333`

The public API is nearly identical to `flutter_markdown`. It uses the same class names
(`MarkdownBody`, `MarkdownStyleSheet`) and properties.

**Soliplex Impact:** Drop-in replacement. It is likely you only need to change the
`pubspec.yaml` dependency and import paths.

### 8. Performance (Widget Tree) -- 6/10

**Reference:** `lib/src/widget.dart:531`

`MarkdownBody` (used in chat bubbles) renders a `Column` containing *all* children. It does
not use lazy loading (`ListView.builder`).

**Soliplex Impact:** A very long markdown message results in a heavy widget tree. Combined
with the re-parsing issue (Axis 4), this makes long chat bubbles expensive.

### 9. Feature Completeness -- 8/10

**Reference:** `lib/src/builder.dart:30` (Block tags), `lib/src/builder.dart:716` (Tables)

Supports GFM (GitHub Flavored Markdown) including Tables, Strikethrough, and Checkboxes.

**Soliplex Impact:** Covers standard chat needs. Does **not** support LaTeX/Math out of the
box (requires a custom syntax/builder extension via `flutter_markdown_plus_latex`).

### 10. Accessibility -- 4/10

**Reference:** `lib/src/_functions_io.dart:20` vs `lib/src/builder.dart:759`

Weak.

1. `_functions_io.dart`'s `kDefaultImageBuilder` accepts `width` and `height`, but
   **ignores** the `alt` text. The `Image.network` created there lacks a `semanticLabel`.
2. Headers (`h1`-`h6`) are rendered as styled text, not wrapped in `Semantics` widgets with
   header traits.

**Soliplex Impact:** Screen readers will read the text, but blind users will miss context on
images and structural navigation.

---

## Scoring Summary

| # | Axis | Score |
|---|------|-------|
| 1 | Native Widget Embedding | 8 |
| 2 | Interactive Elements | 7 |
| 3 | Extensibility | 9 |
| 4 | AI Streaming | 4 |
| 5 | Architecture & Design | 8 |
| 6 | Code Quality | 8 |
| 7 | API Compatibility | 10 |
| 8 | Performance | 6 |
| 9 | Feature Completeness | 8 |
| 10 | Accessibility | 4 |
| | **Average** | **7.2** |

---

## AI Streaming Performance Concern

The specific implementation in `lib/src/widget.dart` poses a performance risk for streaming:

```dart
// lib/src/widget.dart:452
@override
void didUpdateWidget(MarkdownWidget oldWidget) {
  super.didUpdateWidget(oldWidget);
  // IF data changed (which happens every token)
  if (widget.data != oldWidget.data || widget.styleSheet != oldWidget.styleSheet) {
    _parseMarkdown(); // <--- EXPENSIVE OPERATION
  }
}
```

**Recommendation:** For Soliplex, consider debouncing the state updates in the parent widget.
Do not `setState` on every single token if the LLM is fast; update the UI every 100ms or
every 5-10 tokens to reduce the frequency of `_parseMarkdown`.

---

## Migration Risk Assessment

| Risk Area | Level | Notes |
|---|---|---|
| Migration Effort | Very Low | API is 99% compatible |
| Regression Risk | Low | Rendering logic is standard |
| Accessibility Risk | Medium | Default image builder drops alt text semantics |
| Streaming Risk | Medium-High | Full rebuild per token, same as current |

**Recommendation:** Implement a custom `imageBuilder` that passes `alt` to the `Image`
widget's `semanticLabel` to address the accessibility gap.

---

## Architecture Diagram

```text
Soliplex Chat Bubble
       |
       v
+----------------+      (Data String)      +----------------+
|  MarkdownBody  | ----------------------> |   md.Document  |
+----------------+                         +----------------+
       |                                           |
       | (didUpdateWidget)                         | (AST Nodes)
       v                                           v
+----------------+      (Visitor)          +----------------+
| MarkdownBuilder| <---------------------- |  Markdown      |
+----------------+                         |  StyleSheet    |
       |                                   +----------------+
       | (Constructs Widgets)
       |
       +---> [Builders Map] (Custom Syntax Highlighting)
       |
       v
+---------------------------+
| Column (Main Axis)        |
|   +-- Text.rich (P)       |
|   +-- ScrollBar (Pre)     |
|   +-- Table               |
+---------------------------+
```
