# Audit Report: `flutter_markdown_plus` v1.0.7

**Auditor:** OpenAI Codex
**Date:** 2026-02-10
**Package:** [flutter_markdown_plus](https://pub.dev/packages/flutter_markdown_plus) v1.0.7
**Context:** Soliplex AI chat application migration evaluation

---

## Scoring Summary

| # | Axis | Score |
|---|------|-------|
| 1 | Native Widget Embedding | 6 |
| 2 | Interactive Elements | 5 |
| 3 | Extensibility | 8 |
| 4 | AI Streaming | 3 |
| 5 | Architecture & Design | 7 |
| 6 | Code Quality | 7 |
| 7 | API Compatibility | 9 |
| 8 | Performance | 5 |
| 9 | Feature Completeness | 6 |
| 10 | Accessibility | 4 |
| | **Average** | **6.0** |

---

## Detailed Axis Analysis

### 1. Native Widget Embedding -- 6/10

**References:** `lib/src/widget.dart:265`, `lib/src/widget.dart:367`, `lib/src/builder.dart:192`, `lib/src/builder.dart:397`, `lib/src/builder.dart:487`

**Strengths:**

- Custom element builders can return arbitrary widgets
- Custom block/inline syntaxes allow tag injection and mapping to widgets

**Weaknesses:**

- Embedding is indirect (requires custom syntax + builder)
- No first-class "widget" markdown token

**Migration risks:** Existing custom `CodeBlockBuilder` should port, but any widget-embedding
patterns need custom syntax registration.

### 2. Interactive Elements -- 5/10

**References:** `lib/src/widget.dart:411`, `lib/src/builder.dart:266`, `lib/src/builder.dart:359`, `lib/src/builder.dart:629`

**Strengths:**

- `onTapLink` via gesture recognizers
- Images inherit link tap handling

**Weaknesses:**

- No native support for arbitrary tap targets beyond custom builders
- Link handling is the primary interactive path

**Migration risks:** Modal-open tap flows must be routed through `onTapLink` or custom
builders.

### 3. Extensibility -- 8/10

**References:** `lib/src/widget.dart:265`, `lib/src/widget.dart:367`, `lib/src/widget.dart:285`, `lib/src/builder.dart:192`, `lib/src/builder.dart:219`

**Strengths:**

- `blockSyntaxes`, `inlineSyntaxes`, `builders`, `paddingBuilders`, and `extensionSet` provide
  a flexible extension surface

**Weaknesses:**

- No plugin registry; extensions are all passed via widget params

**Migration risks:** Low; matches flutter_markdown extension points closely.

### 4. AI Streaming -- 3/10

**References:** `lib/src/widget.dart:348`, `lib/src/widget.dart:361`, `lib/src/widget.dart:374`, `lib/src/builder.dart:980`

**Strengths:**

- Deterministic rebuilds; stable behavior

**Weaknesses:**

- Every token update re-parses the entire markdown and rebuilds the widget tree
- Unique keys reduce subtree reuse

**Migration risks:** High for streaming UX; may cause jank or GC churn during token-by-token
updates.

### 5. Architecture & Design -- 7/10

**References:** `lib/src/widget.dart:192`, `lib/src/widget.dart:337`, `lib/src/builder.dart:76`, `lib/src/style_sheet.dart:8`

**Strengths:**

- Clean separation between widget, builder, and style
- Delegate pattern isolates link and code formatting

**Weaknesses:**

- Global mutable `_kBlockTags` is extended per build (`lib/src/builder.dart:192`), which is
  surprising state

**Migration risks:** Low; structure is close to flutter_markdown.

### 6. Code Quality -- 7/10

**References:** `lib/src/builder.dart:253`, `lib/src/builder.dart:192`, `lib/src/_functions_io.dart:58`

**Strengths:**

- Clear naming, good use of Dart idioms, doc comments
- Safe image error handling

**Weaknesses:**

- TODO with ignored lint for mutable `TableRow` children
- Global list mutation
- No explicit error handling around markdown parse

**Migration risks:** Low; but streaming usage may reveal performance-related issues.

### 7. API Compatibility -- 9/10

**References:** `lib/src/widget.dart:202`, `lib/src/widget.dart:445`, `lib/src/widget.dart:499`

**Strengths:**

- `Markdown`/`MarkdownBody`, `MarkdownStyleSheet`, builders, and syntax hooks closely mirror
  `flutter_markdown`

**Weaknesses:**

- Minor differences in defaults (e.g., `fitContent`, `softLineBreak`, `styleSheetTheme`)

**Migration risks:** Low; Soliplex's current usage maps cleanly.

### 8. Performance -- 5/10

**References:** `lib/src/widget.dart:348`, `lib/src/builder.dart:743`, `lib/src/builder.dart:822`, `lib/src/builder.dart:980`

**Strengths:**

- Merges adjacent text spans
- Wraps inline content efficiently
- Tables handle horizontal scrolling

**Weaknesses:**

- Full rebuild on data changes
- Pervasive `UniqueKey` on text widgets prevents widget reuse
- Wrap can be costly with long streams

**Migration risks:** Medium for long chat histories and streaming updates.

### 9. Feature Completeness -- 6/10

**References:** `lib/src/widget.dart:367`, `lib/src/builder.dart:441`, `lib/src/builder.dart:344`, `lib/src/builder.dart:599`, `lib/src/widget.dart:559`

**Strengths:**

- GFM extension set, tables, task lists, code blocks, images, blockquotes

**Weaknesses:**

- No built-in LaTeX/math rendering
- No mention of footnotes or advanced GFM extras

**Migration risks:** Medium if Soliplex expects math or custom extensions.

### 10. Accessibility -- 4/10

**References:** `lib/src/builder.dart:599`, `lib/src/builder.dart:637`, `lib/src/builder.dart:980`

**Strengths:**

- Uses `SelectableText`/`Text.rich` for readable text and selection

**Weaknesses:**

- Images lack semantic labels from `alt`
- Checkboxes are icons without semantics
- Link semantics rely on text only

**Migration risks:** Medium for accessibility compliance; may need wrappers/custom builders.

---

## AI Streaming Performance Concerns

Codex identified the following specific concerns for Soliplex's streaming use case:

1. **Full markdown parse and widget rebuild on every `data` change**
   (`lib/src/widget.dart:348`, `lib/src/widget.dart:361`)

2. **`UniqueKey` on every text span prevents widget reuse**, increasing rebuild cost
   (`lib/src/builder.dart:980`)

3. **Link recognizers are disposed and recreated per parse**
   (`lib/src/widget.dart:400`), adding GC churn

4. **Wrap-based inline layout and span merging can become expensive** for long token streams
   (`lib/src/builder.dart:743`, `lib/src/builder.dart:822`)

---

## Architecture Diagram

```text
Markdown/MarkdownBody
        |
        v
  MarkdownWidgetState
        |
        v
  md.Document.parseLines
        |
        v
  MarkdownBuilder (NodeVisitor)
        |
        v
  Widget Tree (Text/SelectableText, Wrap, Column, Table, Image, etc.)
```

---

## Migration Risk Assessment

| Risk | Level | Driver |
|---|---|---|
| Overall | Medium | |
| API Compatibility | Low | 99% drop-in replacement |
| Streaming Performance | High | Full rebuild per token, UniqueKey prevents reuse |
| Accessibility | Medium | Images, checkboxes, headers lack semantics |
| Feature Gaps | Medium | No built-in LaTeX/math |

---

## Verdict

Codex rates `flutter_markdown_plus` as a **medium-quality** option for Soliplex. The API
compatibility is excellent (near drop-in replacement), but the lack of incremental rendering
and accessibility gaps are significant concerns for a production AI chat application. The
streaming performance issue is the most critical: at 20-50 tokens/second, the full-rebuild
architecture will cause measurable jank on longer responses.
