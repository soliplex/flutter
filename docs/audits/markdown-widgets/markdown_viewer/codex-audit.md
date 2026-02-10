# markdown_viewer v0.6.2 -- Codex Audit

**Auditor:** OpenAI Codex (via MCP)
**Date:** 2026-02-10
**Source:** <https://github.com/tagnote-app/markdown_viewer>
**pub.dev:** <https://pub.dev/packages/markdown_viewer>

---

## 1. Package Overview

- Purpose: Flutter widget that parses Markdown and builds a widget tree with styling, link handling, images, tables, code blocks, and some extensions (task list, footnotes, kbd, sub/superscript). Entry point is `MarkdownViewer` which parses text and renders widgets (`lib/src/widget.dart:10-163`).
- Dependencies: `dart_markdown ^3.1.7` plus Flutter SDK only (`pubspec.yaml`).
- Publisher reputation: tagnote.app (verified), 24 likes, 90 pub points, 1.5k downloads; last update May 2023 (stale).

## 2. Architecture Analysis

### Pipeline

1. `MarkdownViewer` builds a `dart_markdown.Markdown` parser and parses text into `md.Node` (`lib/src/widget.dart:97-131`).
2. `AstTransformer` converts `md.Node` to internal AST (`MarkdownElement` / `MarkdownText`), normalizes node types, and appends footnote references (`lib/src/transformer.dart:8-124`, `lib/src/ast.dart:9-73`).
3. `MarkdownRenderer` walks the internal AST, consults registered `MarkdownElementBuilder`s, builds `TextSpan`s and widgets, and merges adjacent `RichText` where possible (`lib/src/renderer.dart:27-310`, `lib/src/helpers/merge_rich_text.dart:3-114`).
4. Builders convert AST nodes into widgets and styles (`lib/src/builders/*.dart`).
5. Final widget tree is a `Column` or single widget based on children count (`lib/src/widget.dart:149-162`).

### ASCII Architecture Diagram

```text
MarkdownViewer (StatefulWidget)
    |
    | parse()
    v
dart_markdown AST (md.Node)
    |
    | AstTransformer.transform()
    v
Internal AST (MarkdownElement/MarkdownText)
    |
    | MarkdownRenderer (Visitor)
    | - builder registry
    | - style merge
    | - text span creation
    v
Widgets + RichText
    |
    | mergeRichText (optional compression)
    v
Final Widget Tree (Column/child)
```

### Builder Pattern

- Each element type maps to a `MarkdownElementBuilder` via `matchTypes`; custom builders can override defaults by registering in `elementBuilders` (`lib/src/renderer.dart:55-144`, `lib/src/builders/builder.dart:10-141`).
- Inline elements are constrained to `RichText`/`Text`/`DefaultTextStyle` unless treated as block elements (`lib/src/renderer.dart:269-334`, `lib/src/builders/builder.dart:121-123`).

## 3. Source Code Walkthrough

- **`lib/src/widget.dart`:** `MarkdownViewer` parsing, render orchestration, SelectionArea wrapping, `nodesFilter` hook (`lib/src/widget.dart:10-163`).
- **`lib/src/renderer.dart`:** Core rendering visitor, builder registry, selection handling, link recognizers, inline merge (`lib/src/renderer.dart:27-310`).
- **`lib/src/transformer.dart`:** AST normalization, type mapping, footnote reference aggregation (`lib/src/transformer.dart:8-124`).
- **`lib/src/builders/builder.dart`:** Base builder API, style merge, widget creation rules, inline constraints (`lib/src/builders/builder.dart:10-141`).
- **`lib/src/builders/*`:**
  - `link_builder.dart`: Tap recognizer with `onTapLink` callback (`lib/src/builders/link_builder.dart:7-37`).
  - `image_builder.dart`: Image resolution, optional size parsing, URI handling (`lib/src/builders/image_builder.dart:9-110`).
  - `code_block_builder.dart`: Code block styling, horizontal scroll, copy button (`lib/src/builders/code_block_builder.dart:8-113`).
  - `table_bilder.dart`: Table layout with row decorations and horizontal scroll (`lib/src/builders/table_bilder.dart:1-114`).
  - `list_builder.dart`: Ordered/bullet/task lists with custom markers (`lib/src/builders/list_builder.dart:7-161`).
  - `simple_inlines_builder.dart`, `headline_builder.dart`, `blockquote_builder.dart`, `code_span_builder.dart`, `thematic_break_builder.dart`, `footnote_builder.dart`: standard markdown elements.
- **`lib/src/helpers/merge_rich_text.dart`:** Compresses adjacent `RichText`, uses `Wrap` when needed (`lib/src/helpers/merge_rich_text.dart:3-114`).
- **`lib/src/selection/*`:** Custom selection toolbar implementations, but not used by `MarkdownViewer` (no references).
- **`lib/src/style.dart`:** `MarkdownStyle` configuration (analog to `MarkdownStyleSheet`) (`lib/src/style.dart:5-113`).

## 4. Scoring Table (1-10)

| Category | Score | Justification |
|---|---:|---|
| Native Widget Embedding | 5 | Custom builders can return arbitrary widgets for block elements, but inline widgets are constrained to `RichText`/`Text`/`DefaultTextStyle` unless you treat them as blocks (`lib/src/renderer.dart:269-334`, `lib/src/builders/builder.dart:121-123`). |
| Interactive Elements | 6 | Link taps supported via `MarkdownTapLinkCallback` (`lib/src/builders/link_builder.dart:7-37`); custom builders can add other interactions, but no built-in gesture hooks beyond links. |
| Extensibility | 7 | `syntaxExtensions` + `elementBuilders` provide a clear extension mechanism (`lib/src/widget.dart:27-122`, `lib/src/renderer.dart:140-144`); must manually map new element types to builders. |
| AI Streaming | 4 | Entire markdown is parsed and rendered on every build; no incremental/delta render (`lib/src/widget.dart:97-147`). |
| Architecture and Design | 7 | Clean separation between parsing, AST transform, and rendering; builder registry is straightforward (`lib/src/transformer.dart`, `lib/src/renderer.dart`, `lib/src/builders/builder.dart`). |
| Code Quality | 6 | Generally readable, but a few sharp edges (assert-only guards, deprecated Flutter API, unused selection code). |
| API Compatibility | 4 | API diverges from `flutter_markdown` (`MarkdownViewer` vs `MarkdownBody`, different style classes and builders). |
| Performance | 5 | `mergeRichText` reduces widget count, but full rebuilds, many `Column`/`Wrap` nodes, and no virtualization. |
| Feature Completeness | 7 | Tables, code blocks, images, task lists, footnotes, strikethrough, autolink, sub/superscript, kbd supported; raw HTML disabled. |
| Accessibility | 4 | Images ignore alt text in default builder; links rely on `RichText` semantics with no explicit labels; selection toolbars are custom but unused. |

**Total: 55/100**

## 5. Critical Issues

- **High: Potential local file access and non-web compatibility.** `ImageBuilder` imports `dart:io` and falls back to `Image.file` for any non-http/data/resource URI, including relative paths, which can read local files when markdown is untrusted and will fail on web builds (`lib/src/builders/image_builder.dart:1,94-110`).
- **High: Unknown element types crash in release.** Renderer asserts for missing builders, then immediately dereferences `_builders[type]!`; in release builds, `assert` is stripped, so custom syntax that emits an unmapped element type will throw (`lib/src/renderer.dart:183-205`).
- **Medium: No incremental rendering.** Streaming token updates will repeatedly parse and rebuild the full widget tree (`lib/src/widget.dart:97-147`).
- **Low: Deprecated text theme usage.** Uses `textTheme.bodyText2`, which is deprecated in Material 3 (`lib/src/renderer.dart:46-52`).
- **Low: Unused selection toolbar code.** Custom selection toolbars exist but are never wired in, which suggests incomplete selection customization (`lib/src/selection/*.dart`).

## 6. Migration Path (flutter_markdown to markdown_viewer)

1. Replace `MarkdownBody` with `MarkdownViewer` (`lib/src/widget.dart:10-163`).
2. Map `MarkdownStyleSheet` to `MarkdownStyle`. Some fields are renamed (e.g., `headline1`...`headline6`, `paragraphPadding`, `codeblockPadding`, `tableRowDecoration`).
3. Convert custom `builders` to `MarkdownElementBuilder` implementations and pass them via `elementBuilders`.
4. Move `MarkdownBody.onTapLink` logic to `MarkdownViewer.onTapLink` (same data, different typedef) (`lib/src/builders/link_builder.dart:7-37`).
5. Code block highlighting: port your `CodeBlockBuilder` to `highlightBuilder` (returns `List<TextSpan>`) (`lib/src/builders/code_block_builder.dart:40-63`).
6. If you add custom syntax, pass `dart_markdown` `Syntax` via `syntaxExtensions` and register a builder for each emitted element type (to avoid runtime crashes).
7. For image behavior, implement `imageBuilder` to enforce safe URI schemes and to use your existing caching/placeholder pipeline.

## 7. Verdict

**Conditional.**

The package has a clean builder-based architecture and is extensible via custom syntax + builders, but it is not a drop-in replacement for `flutter_markdown`, has no incremental rendering for streaming responses, and the default image handling is both non-web compatible and risky for untrusted content (`lib/src/builders/image_builder.dart:1,94-110`).

If Soliplex can constrain markdown to trusted sources and accept block-level widget embedding (not inline), it can work; otherwise, expect to carry custom patches or fork it.

### Potential Follow-up Actions

1. Draft a hardening plan (image scheme allowlist, web-safe image handling, missing builder guard).
2. Sketch a compatibility shim mapping `flutter_markdown` APIs to this package.
3. Evaluate a fork strategy for streaming/delta rendering.
