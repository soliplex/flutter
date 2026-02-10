# flutter_smooth_markdown -- Codex Audit

**Auditor:** OpenAI Codex (via MCP)
**Date:** 2026-02-10
**Package:** `flutter_smooth_markdown` v0.6.1
**Source:** `~/dev/markdown-audit/flutter_smooth_markdown/`
**License:** MIT | **Publisher:** Unverified | **Pub Points:** 150 | **Likes:** 6

---

## Scoring Table

| # | Axis | Score | Evidence (code refs) |
|---|------|:-----:|----------------------|
| 1 | Native Widget Embedding | 6 | Custom nodes can render arbitrary widgets via builder registry (`widget_builder.dart:105-160`, `markdown_renderer.dart:302-327`), inline rendering wraps non-text widgets via `WidgetSpan` (`markdown_renderer.dart:256-270`). No built-in markdown syntax for widget embedding beyond plugins (`parser_plugin.dart:37-335`). |
| 2 | Interactive Elements | 5 | Links tappable via callbacks (`link_builder.dart:34-41`, `enhanced_link_builder.dart:99-107`), details blocks expand/collapse (`details_builder.dart:115-151`), code blocks have copy UI (`enhanced_code_block_builder.dart:189-207`). No built-in modal actions; requires app-side handling. |
| 3 | Extensibility | 8 | Formal plugin system for block/inline parsing (`parser_plugin.dart:37-335`) and builder registry for custom rendering (`widget_builder.dart:105-160`, `markdown_renderer.dart:302-327`). `SmoothMarkdown` wires plugins/builders (`smooth_markdown.dart:484-593`). |
| 4 | AI Streaming | 5 | Streaming widget buffers and re-renders entire content each update (`stream_markdown.dart:275-363`), with 50ms throttle (`stream_markdown.dart:281-312`). No delta/partial AST updates; scales poorly for long outputs. |
| 5 | Architecture & Design | 6 | Clear parser/renderer separation (`markdown_parser.dart:32-175`, `markdown_renderer.dart:24-215`). However, `MarkdownConfig` is accepted but unused in parsing/rendering (`smooth_markdown.dart:255-273`, `smooth_markdown.dart:535-553`). |
| 6 | Code Quality | 5 | Good documentation, but notable gaps: `MarkdownConfig` unused (`smooth_markdown.dart:255-273`), `parseAsync` is sync-wrapped (`markdown_parser.dart:69-74`), and `StreamMarkdown.errorBuilder` is not used (`stream_markdown.dart:236-259`, `stream_markdown.dart:314-316`). |
| 7 | API Compatibility | 4 | API surface differs: `SmoothMarkdown` replaces `MarkdownBody`, `onTapLink` only provides URL (`smooth_markdown.dart:166-209`, `smooth_markdown.dart:275-298`). Custom parser/AST rather than `package:markdown`. |
| 8 | Performance | 6 | Parse cache and RepaintBoundary help static lists (`parse_cache.dart:1-133`, `smooth_markdown.dart:532-607`). Streaming re-parses full text (`stream_markdown.dart:320-362`) and renderer builds full `Column` with no virtualization (`markdown_renderer.dart:200-215`). |
| 9 | Feature Completeness | 6 | Tables (`block_parser.dart:466-539`), task lists (`block_parser.dart:352-370`), strikethrough (`inline_parser.dart:95-103`), code blocks (`block_parser.dart:169-209`), images (`inline_parser.dart:140-195`), LaTeX (`inline_parser.dart:86-115`, `block_parser.dart:211-239`), Mermaid (`mermaid_plugin.dart:41-117`). Missing: autolinks declared but not implemented (`markdown_config.dart:170-174`), no HTML parsing. |
| 10 | Accessibility | 3 | Links/images lack Semantics/labels (`link_builder.dart:34-41`, `image_builder.dart:58-75`), general text is `Text`/`RichText` without explicit semantics or selection (`markdown_renderer.dart:273-278`). |

**Codex Weighted Total: 54/100**

---

## Detailed Findings

### 1. Native Widget Embedding (6/10)

Custom AST nodes can render arbitrary widgets through the builder registry
system. The renderer wraps non-text widgets in `WidgetSpan` for inline
embedding. However, there is no built-in markdown syntax for widget embedding
-- it requires implementing a complete plugin+builder chain.

**Key code:**

- `lib/src/renderer/widget_builder.dart:105-160` (BuilderRegistry)
- `lib/src/renderer/markdown_renderer.dart:256-270` (WidgetSpan wrapping)
- `lib/src/parser/parser_plugin.dart:37-335` (Plugin system)

### 2. Interactive Elements (5/10)

Links are tappable via callbacks. The `EnhancedLinkBuilder` adds hover effects.
Details blocks support expand/collapse. Code blocks have copy-to-clipboard UI.
However, no built-in modal or dialog support -- all requires app-side handling.

**Key code:**

- `lib/src/renderer/builders/link_builder.dart:34-41`
- `lib/src/renderer/builders/enhanced_link_builder.dart:99-107`
- `lib/src/renderer/builders/details_builder.dart:115-151`
- `lib/src/renderer/builders/enhanced_code_block_builder.dart:189-207`

### 3. Extensibility (8/10)

Formal plugin system with block and inline parser plugins, plus a builder
registry for custom rendering. The `SmoothMarkdown` widget properly wires
plugins and builders together.

**Key code:**

- `lib/src/parser/parser_plugin.dart:37-335`
- `lib/src/renderer/widget_builder.dart:105-160`
- `lib/widgets/smooth_markdown.dart:484-593`

### 4. AI Streaming (5/10)

The streaming widget buffers all content and re-renders the entire accumulated
string on each update. A 50ms throttle batches rapid updates, but there are no
delta or partial AST updates. This approach scales poorly for long outputs.

**Key code:**

- `lib/widgets/stream_markdown.dart:275-363`
- `lib/widgets/stream_markdown.dart:281-312` (throttle)

### 5. Architecture & Design (6/10)

Clear parser/renderer separation with a well-organized directory structure.
However, `MarkdownConfig` is accepted as a parameter but never used in parsing
or rendering logic -- the feature flags (`enableCodeHighlight`, `enableTables`,
etc.) have no effect.

**Key code:**

- `lib/src/parser/markdown_parser.dart:32-175`
- `lib/src/renderer/markdown_renderer.dart:24-215`
- `lib/widgets/smooth_markdown.dart:255-273` (config accepted but unused)

### 6. Code Quality (5/10)

Good documentation throughout, but several notable gaps:

- `MarkdownConfig` is dead code (accepted but unused)
- `parseAsync` wraps synchronous parsing in `Future.value()`
- `StreamMarkdown.errorBuilder` parameter is accepted but never used
- Stream subscription is not cancelled on dispose or widget update

**Key code:**

- `lib/src/parser/markdown_parser.dart:69-74` (fake async)
- `lib/widgets/stream_markdown.dart:236-259` (unused errorBuilder)
- `lib/widgets/stream_markdown.dart:314-316` (silent error swallowing)

### 7. API Compatibility with flutter_markdown (4/10)

Significant API differences from `flutter_markdown`:

- `SmoothMarkdown` replaces `MarkdownBody` with different parameter names
- `onTapLink` only provides URL (flutter_markdown provides text, href, title)
- Uses custom parser/AST instead of `package:markdown`
- Builder interface is different (`MarkdownWidgetBuilder` vs
  `MarkdownElementBuilder`)
- No `selectable` parameter equivalent

### 8. Performance (6/10)

Parse cache and RepaintBoundary help static content performance. However,
streaming re-parses the full text on every update, and the renderer builds a
flat `Column` with no virtualization or lazy loading.

**Key code:**

- `lib/src/parser/parse_cache.dart:1-133` (LRU cache)
- `lib/widgets/smooth_markdown.dart:532-607` (cache + RepaintBoundary)
- `lib/widgets/stream_markdown.dart:320-362` (full re-parse)
- `lib/src/renderer/markdown_renderer.dart:200-215` (flat Column)

### 9. Feature Completeness (6/10)

Supports tables, task lists, strikethrough, code blocks with syntax
highlighting, images, LaTeX (inline and block), and Mermaid diagrams. However,
autolinks are declared in config but not implemented, and HTML parsing is not
supported.

### 10. Accessibility (3/10)

Links and images lack `Semantics` widgets and labels. General text rendering
uses `Text`/`RichText` without explicit semantics or selection support.

---

## Claim Verification

| Claim | Verdict | Evidence |
|-------|---------|----------|
| AST-based parsing | **Yes** | Dedicated AST nodes and parser (`markdown_node.dart:1-20`, `markdown_parser.dart:6-67`) |
| Real-time streaming | **Partial** | `StreamMarkdown` exists but reparses entire buffer per chunk (`stream_markdown.dart:275-363`) |
| Mermaid diagrams | **Yes** | Mermaid parser plugin + native widget renderer (`mermaid_plugin.dart:41-117`, `mermaid_builder.dart:10-182`) |
| LaTeX support | **Yes** | Inline + block parsing and `flutter_math_fork` renderers |
| Plugin architecture | **Yes** | Parser plugins and builder registry (`parser_plugin.dart:37-335`, `widget_builder.dart:105-160`) |
| Theme presets | **Yes** | Built-in `MarkdownStyleSheet` factories (`style_sheet.dart:169-463`) |

---

## Codex's Overall Recommendation

Given Soliplex's requirements (native widget embedding, interactive elements,
custom syntax/renderers, plugin architecture, and excellent streaming
performance), this package is close on extensibility but not on streaming
performance or API compatibility.

It provides a strong plugin/builders foundation and Mermaid/LaTeX support, but:

- Streaming is full re-parse per chunk
- `MarkdownConfig` is unused dead code
- Autolinks/HTML are missing despite being declared
- Accessibility is minimal

**Would not ship this as-is for production AI streaming chat** without a
targeted fork to:

1. Implement incremental parsing
2. Enforce config toggles
3. Add semantics
4. Improve GFM compliance
