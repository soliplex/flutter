# flutter_smooth_markdown -- Gemini Audit

**Auditor:** Gemini 2.5 Pro (via MCP)
**Date:** 2026-02-10
**Package:** `flutter_smooth_markdown` v0.6.1
**Source:** `~/dev/markdown-audit/flutter_smooth_markdown/`
**License:** MIT | **Publisher:** Unverified | **Pub Points:** 150 | **Likes:** 6

---

## Scoring Table

| # | Axis | Score | Evidence |
|---|------|:-----:|---------|
| 1 | Native Widget Embedding | 9 | Possible via plugin+builder+WidgetSpan; no built-in syntax but architecture fully supports it |
| 2 | Interactive Elements | 10 | `onTapLink` callback is first-class; `EnhancedLinkBuilder` uses `GestureDetector` with hover animations |
| 3 | Extensibility | 10 | Formal plugin system (`BlockParserPlugin`/`InlineParserPlugin`) + `BuilderRegistry`; 8 example plugins |
| 4 | AI Streaming | 3 | Full re-parse/re-render per chunk; 50ms throttle mitigates but does not solve O(n) scaling |
| 5 | Architecture & Design | 9 | Excellent parser/renderer separation; AST-based; well-organized directory structure |
| 6 | Code Quality | 7 | Well-documented APIs; but stream errors silently ignored, `errorBuilder` unimplemented, misleading comments |
| 7 | API Compatibility | 8 | Similar concepts (`data`, `styleSheet`, `onTapLink`, `codeBuilder`); migration straightforward for core usage |
| 8 | Performance | 6 | Excellent static (LRU cache + RepaintBoundary); poor streaming (cache disabled, full re-parse) |
| 9 | Feature Completeness | 10 | GFM, tables, LaTeX, Mermaid, AI blocks, footnotes, details/summary, theme presets |
| 10 | Accessibility | 2 | Zero `Semantics` widgets in any builder; no screen reader support for headers, links, images |

**Gemini Weighted Total: 74/100**

---

## Detailed Analysis

### 1. Native Widget Embedding (9/10)

The package is designed for this via its plugin and builder architecture. While
there is no direct `![widget]` syntax, you can create a custom syntax, a parser
plugin for it, and a widget builder to render any Flutter widget.

1. **Define a Plugin:** Create a `BlockParserPlugin` or `InlineParserPlugin` to
   parse your custom syntax. See `lib/src/parser/parser_plugin.dart`.
2. **Define a Custom Node:** The plugin's `parse` method returns a custom
   `MarkdownNode`.
3. **Register Plugin and Builder:** In the `SmoothMarkdown` widget, provide the
   plugin and a corresponding builder via `builderRegistry`.

The renderer handles non-text widgets via `WidgetSpan`:

```dart
// markdown_renderer.dart:267-269
return WidgetSpan(
  alignment: PlaceholderAlignment.middle,
  child: widget,
);
```

**Concerns for Soliplex:** Extremely powerful but requires boilerplate for each
custom widget type. The architecture fully supports it, but it is not
out-of-the-box.

### 2. Interactive Elements (10/10)

The package provides a first-class `onTapLink` callback, which is exactly what
Soliplex needs to intercept link clicks and trigger custom actions like opening
a modal.

```dart
// smooth_markdown.dart:298
final void Function(String url)? onTapLink;
```

The `EnhancedLinkBuilder` demonstrates a perfect implementation:

```dart
// enhanced_link_builder.dart:103-106
child: GestureDetector(
  onTap: () {
    widget.context.onTapLink?.call(widget.url);
  },
)
```

**Concerns for Soliplex:** None. Perfect fit for modal-on-click requirement.

### 3. Extensibility (10/10)

Extensibility is a core design principle, exposed through two clear mechanisms:

1. **Parser Plugins (`ParserPluginRegistry`):** Clean separation of
   `BlockParserPlugin` and `InlineParserPlugin`. The AI-specific plugins
   (`ThinkingPlugin`, `ArtifactPlugin`) serve as excellent examples.
2. **Widget Builders (`BuilderRegistry`):** Customizable rendering for any AST
   node, including overriding default ones.

**Concerns for Soliplex:** None. Robust architecture for custom syntax and
rendering needs.

### 4. AI Streaming (3/10)

**Critical failure point.** The `StreamMarkdown` widget accumulates the entire
stream content and re-parses/re-renders everything on each update.

```dart
// stream_markdown.dart:295
_buffer.write(chunk);
// ...
// stream_markdown.dart:322
_currentText = _buffer.toString();
// ...
// stream_markdown.dart:349-359
return SmoothMarkdown(
  data: _currentText,
  enableCache: false, // Cache is explicitly disabled
);
```

The documentation is honest about this: "The widget re-parses and re-renders
the entire accumulated content on each chunk."

**Concerns for Soliplex:** This is a deal-breaker in its current state. Rapid
token-by-token streaming of long AI responses will cause significant performance
degradation, high CPU usage, and UI jank.

### 5. Architecture & Design (9/10)

The package demonstrates excellent separation of concerns:

- **Parsing:** `src/parser/` contains AST, parsers, and plugin system
- **Rendering:** `src/renderer/` contains core renderer and builders
- **Configuration:** `src/config/` holds `MarkdownConfig` and `MarkdownStyleSheet`
- **Widgets:** Public-facing widgets are kept separate from core logic

The design relies on proven patterns (AST, Builder, Plugin) and is
well-organized.

**Concerns for Soliplex:** Only weakness is the naive streaming implementation.

### 6. Code Quality (7/10)

**Pros:** Well-documented with excellent doc comments on all public APIs. Naming
is clear and consistent. Dart idioms like `const` constructors and `final`
properties are used correctly.

**Cons:** Error handling is weak in the streaming widget:

```dart
// stream_markdown.dart:314-316
onError: (error) {
  // Error will be handled by StreamBuilder  // Misleading, no StreamBuilder exists
},
```

The `errorBuilder` parameter is accepted but not implemented.

**Concerns for Soliplex:** Lack of error handling in `StreamMarkdown` is a
production risk. A network error in our AI response stream could cause silent
failure.

### 7. API Compatibility (8/10)

The API surface is very similar to `flutter_markdown`:

- `MarkdownBody` -> `SmoothMarkdown` (same concepts)
- `data`, `styleSheet`, `onTapLink` -> identical names
- `builders` -> `builderRegistry`
- `extensionSet` -> `plugins`
- `codeBuilder` is a convenient shortcut

**Concerns for Soliplex:** Migration will be relatively straightforward. Custom
`CodeBlockBuilder` logic can be easily ported. `MarkdownStyleSheet` for Material
3 will need adaptation.

### 8. Performance (6/10)

Mixed results:

- **Excellent for static content:** LRU cache (`MarkdownParseCache`) is a major
  advantage over `flutter_markdown`. Default `RepaintBoundary` wrapping improves
  list performance.
- **Poor for streaming content:** As detailed in axis #4, streaming performance
  is algorithmically inefficient. Cache is disabled for `StreamMarkdown`.

**Concerns for Soliplex:** Static message rendering in chat history would be
excellent. Performance during active streaming would be poor.

### 9. Feature Completeness (10/10)

Supports everything `flutter_markdown` does and more:

- **GFM / Tables:** `TableNode` in `markdown_node.dart`, table parsing in
  `block_parser.dart`
- **LaTeX:** `InlineMathNode` and `BlockMathNode`
- **Mermaid:** Dedicated parser and native renderer
- **AI-specific:** `<thinking>` and `<artifact>` blocks

**Concerns for Soliplex:** None. Feature set is more comprehensive than current
solution.

### 10. Accessibility (2/10)

Near-total lack of accessibility considerations. No `Semantics` widgets in any
builder:

- Headers rendered as styled `Text`, not `Semantics(header: true, ...)`
- Links in `EnhancedLinkBuilder` are `GestureDetector`s without `Semantics`
- Copy button in `EnhancedCodeBlockBuilder` lacks semantic label

**Concerns for Soliplex:** This is a **major regression** and a production
blocker.

---

## Claim Verification

| Claim | Verdict | Evidence |
|-------|---------|----------|
| AST-based parsing | **VERIFIED** | Full AST in `markdown_node.dart` |
| Real-time streaming | **MISLEADING** | Widget exists but brute-force re-render approach |
| Mermaid diagrams | **VERIFIED** | Dedicated parser + renderer |
| LaTeX support | **VERIFIED** | `InlineMathNode`/`BlockMathNode` + `flutter_math_fork` |
| Plugin architecture | **VERIFIED** | Robust `ParserPluginRegistry` |
| Theme presets | **VERIFIED** | `.light()`, `.dark()`, `.github()`, `.vscode()`, `.fromTheme()`, `.fromBrightness()` |

---

## Migration Difficulty Assessment

**Difficulty: Medium**

- **Easy:** Core widget usage, `onTapLink` callback, `StyleSheet` concepts
- **Medium:** Custom `CodeBlockBuilder` adaptation to `MarkdownWidgetBuilder`
- **Hard:** Accessibility wrappers for all builders; replacing/modifying
  `StreamMarkdown` for performance

---

## Gemini's Overall Recommendation: DO NOT MIGRATE (in its current state)

Despite promising architecture, excellent extensibility, and rich feature set,
`flutter_smooth_markdown` v0.6.1 is not suitable for production use in Soliplex.

**Two critical blocking issues:**

1. **Inefficient Streaming Implementation:** Token-by-token AI response display
   would suffer severe performance issues.
2. **Lack of Accessibility:** Absence of semantic information is a major
   regression.

**Path Forward Options:**

1. **Fork and Fix:** Implement incremental streaming renderer and add
   accessibility semantics. Significant effort but would result in a
   best-in-class package.
2. **Stay on flutter_markdown:** Build missing features (LaTeX, Mermaid) on
   the more mature foundation with better accessibility support.

Given the severity of the issues, the risk and effort of fixing them outweigh
the benefits of migrating at this moment. Monitor for future updates, but for
now: **reject the migration.**
