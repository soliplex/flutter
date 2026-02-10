# flutter_md Audit Report (Codex)

**Package:** flutter_md v0.0.8
**Publisher:** plugfox.dev (Mike Matiunin)
**Repository:** <https://github.com/DoctorinaAI/md>
**License:** MIT
**Auditor:** Codex (OpenAI)
**Date:** 2026-02-10
**Context:** Evaluating for production use in Soliplex AI chat application

---

## Architecture

### File Relationship Diagram

```text
lib/flutter_md.dart
  |-- src/markdown.dart    (Markdown model + plain-text extraction)
  |-- src/nodes.dart       (MD$Block/MD$Span AST)
  |-- src/parser.dart      (MarkdownDecoder + _parseInlineSpans)
  |-- src/theme.dart       (MarkdownThemeData + MarkdownTheme)
  |-- src/render.dart      (MarkdownRenderObject + MarkdownPainter + BlockPainters)
  +-- src/widget.dart      (MarkdownWidget -> RenderObject)
```

### Parse/Render Pipeline

1. Caller builds `Markdown` via `Markdown.fromString(...)` which uses
   `MarkdownDecoder` to split into `MD$Block` nodes and inline `MD$Span` lists
   (`lib/src/markdown.dart:24-32`, `lib/src/parser.dart:39-258`).
2. `MarkdownWidget` creates a `MarkdownRenderObject` with a theme
   (`lib/src/widget.dart:24-57`).
3. `MarkdownRenderObject` delegates layout/paint to `MarkdownPainter`
   (`lib/src/render.dart:18-167`).
4. `MarkdownPainter` maps blocks to `BlockPainter$*` instances (paragraph,
   heading, list, etc.) via the theme's optional builder
   (`lib/src/render.dart:199-255`).
5. Each `BlockPainter` uses `TextPainter` and draws to a `Canvas`; link taps
   are dispatched via recognizers attached to `TextSpan`
   (`lib/src/render.dart:538-587`, `lib/src/render.dart:630-777`).

---

## Source File Walkthrough

### `lib/src/markdown.dart`

- **Purpose:** Immutable wrapper for original markdown string + parsed block list;
  provides `text` reconstruction.
- **Key classes:** `Markdown`, `Markdown.empty`, `Markdown.fromString`.
- **Concern:** `text` reconstruction is O(n) over spans and loses structural
  delimiters; does not preserve original markdown
  (`lib/src/markdown.dart:46-96`).

```dart
factory Markdown.fromString(String markdown) =>
    markdownDecoder.convert(markdown);
```

### `lib/src/nodes.dart`

- **Purpose:** AST types for blocks/spans; bitmask inline styles (`MD$Style`).
- **Key classes:** `MD$Block` sealed class and its variants; `MD$Span`; `MD$Style`.
- **Patterns:** `map/maybeMap` for type-safe dispatch; extension type for bitmask
  styles.
- **Concerns:** `MD$Style` advertises `<url>` autolinks in docs but parser does
  not implement them; image support is modeled (`MD$Style.image`) but renderer
  does not emit `WidgetSpan`.

```dart
@immutable
sealed class MD$Block {
  abstract final String type;
  abstract final String text;
  T map<T>({ ... });
}
```

### `lib/src/parser.dart`

- **Purpose:** Custom block/inline parser, no dependency on `markdown` package.
- **Key classes/functions:** `MarkdownDecoder.convert`, `_parseInlineSpans`.
- **Patterns:** Line-by-line block parsing; inline parsing in two phases (extract
  links/images, then style markers).
- **Concerns:**
  - Block parsing is very limited (no GFM beyond simple tables, no setext
    headings, no indented code, no HTML).
  - Ordered list rendering likely drops "."/")": regex captures only digits, not
    punctuation (`_listPattern`), so items become `1` instead of `1.`
    (`lib/src/parser.dart:32-36`, `lib/src/render.dart:985-993`).
  - Inline parser toggles style flags without stack validation; nested/overlapping
    markup can produce incorrect styling (`lib/src/parser.dart:402-518`).
  - Autolinks `<http://...>` are not parsed despite style docs; images are parsed
    into spans but never rendered.

```dart
if (line.startsWith('```')) { ... pushBlock(MD$Code(...)); }
```

### `lib/src/render.dart`

- **Purpose:** Custom `RenderBox` and painter pipeline; each block is painted
  directly.
- **Key classes:** `MarkdownRenderObject`, `MarkdownPainter`, `BlockPainter`
  and `BlockPainter$*` classes.
- **Patterns:** RenderObject-based rendering; caching last `Picture` by size;
  custom hit-testing for inline link taps.
- **Concerns:**
  - No `Semantics` implementation; screen readers will not read content.
  - No `Selection` integration; `SelectionArea` will not work with a custom
    `RenderBox`.
  - Rendering is paint-only, so there is no native widget embedding (no
    `WidgetSpan` usage; image code is commented out).
  - Link taps are manually hit-tested in multiple block painters; this may miss
    edge cases (overlapping/adjacent spans, gestures in tables/lists).

```dart
final builder = _theme.builder ?? _defaultBlockBuilder;
_blockPainters = filtered.map<BlockPainter>(
  (block) => builder(block, _theme) ?? _defaultBlockBuilder(block, _theme),
).toList(growable: false);
```

### `lib/src/theme.dart`

- **Purpose:** Theme data for markdown rendering + inherited theme wrapper.
- **Key classes:** `MarkdownThemeData`, `MarkdownTheme`.
- **Patterns:** `ThemeExtension`, `copyWith/lerp`, cached text styles by
  `MD$Style`.
- **Concerns:** Customization is limited to styling and block painter replacement;
  no parsing extension hooks.

```dart
final BlockPainter? Function(
  MD$Block block, MarkdownThemeData theme)? builder;
```

### `lib/src/widget.dart`

- **Purpose:** Entry widget that creates a `MarkdownRenderObject`.
- **Key classes:** `MarkdownWidget`.
- **Concerns:** Leaf render object means you cannot inject children/widgets;
  `SelectionArea`/semantics will not be handled here.

```dart
class MarkdownWidget extends LeafRenderObjectWidget { ... }
```

---

## Scoring Table (1-10)

| # | Requirement | Score | Justification |
|---|---|:---:|---|
| 1 | **Native Widget Embedding** | **1** | Rendering is done entirely via `TextPainter` and `Canvas`. There is no `WidgetSpan` usage and the only image embedding code is commented out (`lib/src/render.dart:507-536`). You cannot inject Flutter widgets into the tree. |
| 2 | **Interactive Elements** | **3** | Link taps are supported via `TextSpan` recognizers and manual hit-testing (`lib/src/render.dart:538-587`, `630-777`). There is no general widget/event system, so custom tap targets beyond text spans are not supported. |
| 3 | **Extensibility** | **4** | You can override block painting via `MarkdownThemeData.builder` and filter spans/blocks, but parsing is fixed and there is no extension API for new syntax (`lib/src/theme.dart:152-160`, `lib/src/parser.dart:39-258`). Custom inline parsing would require forking. |
| 4 | **AI Streaming** | **5** | The render path is lean and uses a cached `Picture`, but any update invalidates and rebuilds all block painters (`lib/src/render.dart:259-275`). There is no incremental/delta parsing, so token-by-token updates will reparse and relayout each time. |
| 5 | **Architecture & Design** | **6** | The separation between parsing, AST, theme, and rendering is clear. However, the block parser is minimal and there is no plugin architecture, which limits design scalability for a production chat app. |
| 6 | **Code Quality** | **6** | Code is mostly clean, uses immutable models and type-safe dispatch. Still, there are TODOs and placeholder comments for parsing (`lib/src/parser.dart:66-68`), and several features are partially implemented or commented out. |
| 7 | **API Compatibility** | **2** | The API is not close to `flutter_markdown` (no `MarkdownBody`, `MarkdownStyleSheet`, `MarkdownElementBuilder`). It uses a custom `MarkdownWidget` and `BlockPainter` interface, so Soliplex code would need significant changes. |
| 8 | **Performance** | **7** | A single `RenderBox` with batched `TextPainter` paints is efficient, and the `Picture` cache helps for static content (`lib/src/render.dart:468-494`). For streaming updates, however, the full rebuild will reduce the real-world gains. |
| 9 | **Feature Completeness** | **3** | Supports only headings, quotes, fenced code, lists, horizontal rules, and simple pipe tables. No GFM task lists, images in render, autolinks, HTML, LaTeX, or setext headings. |
| 10 | **Accessibility** | **1** | No semantics configuration or accessibility nodes are provided, and selection is unsupported. This is a blocker for a production chat app with selection and screen readers. |

---

## Critical Issues (Blockers)

1. **Text selection is not supported:** `MarkdownWidget` is a custom `RenderBox`
   without selection/`RenderParagraph` integration, so `SelectionArea` in
   Soliplex will not work (`lib/src/widget.dart:10-57`,
   `lib/src/render.dart:18-167`).

2. **Accessibility is missing:** No `Semantics` is implemented for block content,
   so screen readers cannot access the text (`lib/src/render.dart` lacks
   `describeSemanticsConfiguration`).

3. **No widget embedding:** The renderer is paint-only; interactive widgets
   (buttons/cards), images, or custom Flutter widgets cannot be embedded inside
   markdown (`lib/src/render.dart:507-536`).

4. **Limited markdown feature set:** No GFM task lists, no autolinks, no HTML,
   no LaTeX, no inline image rendering, and partial list/table behavior. This is
   significantly below `flutter_markdown` parity.

5. **Ordered list rendering likely incorrect:** The list marker regex captures
   only digits, which may drop punctuation (`1.` or `1)`), leading to incorrect
   output (`lib/src/parser.dart:32-36`, `lib/src/render.dart:985-993`).

---

## Migration Path (flutter_markdown to flutter_md)

- Replace `MarkdownBody` with `MarkdownWidget` and pre-parse input:
  `Markdown.fromString(markdown)`; you would need to manage parsing outside
  build (as the docs suggest).

- Replace `MarkdownStyleSheet` with `MarkdownThemeData` and wire in Soliplex
  theme values; `MarkdownThemeData.mergeTheme` can help but lacks the extensive
  style surface of `MarkdownStyleSheet`.

- Replace `MarkdownElementBuilder` (e.g., your `CodeBlockBuilder`) with a custom
  `BlockPainter` via `MarkdownThemeData.builder`. This requires re-implementing
  syntax highlighting with `TextPainter`/`TextSpan`, not widgets.

- Remove or rework `SelectionArea`: it will not select text from a custom
  `RenderBox`. You would need to fork flutter_md to integrate selectable text
  or wrap in a separate selectable text system.

- Link handling must be done via `onLinkTap` callback in the theme
  (`lib/src/theme.dart:162-164`).

---

## Verdict

### NO-GO

**Do not adopt `flutter_md` for Soliplex in its current state.**

The lack of selection support and accessibility are hard blockers for a chat
application, and the feature set is far behind `flutter_markdown`. Even if
performance is good, the missing widget embedding, limited syntax coverage, and
custom rendering model would force significant rewrites with questionable UX
parity.

If the team still wanted to explore it, a **conditional** path would require:

1. Adding selection + semantics to the render pipeline (fork)
2. Implementing image rendering and richer markdown features
3. Rebuilding code block rendering to work with `BlockPainter`
