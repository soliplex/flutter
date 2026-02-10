# flutter_smooth_markdown -- Claude Audit

**Auditor:** Claude Opus 4.6
**Date:** 2026-02-10
**Package:** `flutter_smooth_markdown` v0.6.1
**Source:** `~/dev/markdown-audit/flutter_smooth_markdown/`
**License:** MIT | **Publisher:** Unverified | **Pub Points:** 150 | **Likes:** 6

---

## Package Metadata

| Field | Value |
|-------|-------|
| Version | 0.6.0 (pubspec) / 0.6.1 (pub.dev) |
| SDK constraint | `>=3.0.0 <4.0.0` |
| Flutter constraint | `>=3.0.0` |
| Dependencies | `flutter_highlight`, `cached_network_image`, `url_launcher`, `flutter_math_fork`, `flutter_svg` |
| Dev dependencies | `flutter_test`, `flutter_lints`, `mockito`, `build_runner`, `integration_test` |
| Source files | 73 .dart files in lib/ |
| Test infrastructure | Uses `mockito` (not `mocktail`) |

---

## Architecture Diagram

```text
+-------------------------------------------------------------------+
|                    PUBLIC API LAYER                                 |
|  widgets/smooth_markdown.dart   widgets/stream_markdown.dart       |
+-------------------------------------------------------------------+
         |                              |
         v                              v
+-------------------------------------------------------------------+
|                    CONFIGURATION LAYER                              |
|  src/config/markdown_config.dart   src/config/style_sheet.dart     |
+-------------------------------------------------------------------+
         |                              |
         v                              v
+----------------------------+  +-------------------------------+
|     PARSER LAYER           |  |     RENDERER LAYER            |
| src/parser/                |  | src/renderer/                 |
|   markdown_parser.dart     |  |   markdown_renderer.dart      |
|   block_parser.dart        |  |   widget_builder.dart         |
|   inline_parser.dart       |  |   builders/                   |
|   parse_cache.dart         |  |     text_builder.dart         |
|   parser_plugin.dart       |  |     header_builder.dart       |
|   ast/markdown_node.dart   |  |     code_block_builder.dart   |
|   plugins/                 |  |     enhanced_*_builder.dart   |
|     thinking_plugin.dart   |  |     thinking_builder.dart     |
|     artifact_plugin.dart   |  |     artifact_builder.dart     |
|     mention_plugin.dart    |  |     tool_call_builder.dart    |
|     admonition_plugin.dart |  |     mermaid_builder.dart      |
|     emoji_plugin.dart      |  |     ... (20 builders total)   |
|     hashtag_plugin.dart    |  +-------------------------------+
|     mermaid_plugin.dart    |
|     tool_call_plugin.dart  |
+----------------------------+
         |
         v
+----------------------------+
|     MERMAID SUBSYSTEM      |
| src/mermaid/               |
|   parser/ (7 parsers)      |
|   painter/ (7 painters)    |
|   models/ (8 models)       |
|   layout/ (3 engines)      |
|   widgets/mermaid_diagram  |
|   config/responsive_config |
+----------------------------+
```

---

## Source Code Walkthrough

### Entry Points

**`lib/widgets/smooth_markdown.dart`** - The primary stateless widget. Accepts
`data` (markdown string), `styleSheet`, `config`, `onTapLink`, `imageBuilder`,
`codeBuilder`, `useEnhancedComponents`, `enableCache`, `useRepaintBoundary`,
`plugins`, and `builderRegistry`.

```dart
// smooth_markdown.dart:536-553 -- Core build method
final parser = MarkdownParser(plugins: plugins);
final List<MarkdownNode> nodes;
if (enableCache && plugins == null) {
  final cached = _parseCache.get(data);
  if (cached != null) {
    nodes = cached;
  } else {
    nodes = parser.parse(data);
    _parseCache.put(data, nodes);
  }
} else {
  nodes = parser.parse(data);
}
```

**`lib/widgets/stream_markdown.dart`** - A StatefulWidget for streaming. Listens
to a `Stream<String>`, accumulates chunks in a `StringBuffer`, and re-renders
the entire accumulated content via `SmoothMarkdown`.

```dart
// stream_markdown.dart:290-311 -- Streaming logic
widget.stream.listen(
  (chunk) {
    if (!mounted) return;
    _buffer.write(chunk);
    _hasPendingUpdate = true;
    final now = DateTime.now();
    final timeSinceLastUpdate = now.difference(_lastUpdateTime);
    if (timeSinceLastUpdate >= _throttleDuration) {
      _performUpdate();
    } else {
      Future.delayed(_throttleDuration - timeSinceLastUpdate, () {
        if (mounted && _hasPendingUpdate) {
          _performUpdate();
        }
      });
    }
  },
```

### Parser Layer

**`lib/src/parser/ast/markdown_node.dart`** - 21 node types: `TextNode`,
`HeaderNode`, `ParagraphNode`, `CodeBlockNode`, `ListNode`, `ListItemNode`,
`BlockquoteNode`, `HorizontalRuleNode`, `InlineCodeNode`, `BoldNode`,
`ItalicNode`, `StrikethroughNode`, `LinkNode`, `ImageNode`, `TableNode`,
`TableRowNode`, `InlineMathNode`, `BlockMathNode`, `FootnoteReferenceNode`,
`FootnoteDefinitionNode`, `DetailsNode`. Each has `type`, `toJson()`,
`copyWith()`.

**`lib/src/parser/block_parser.dart`** - Hand-written line-by-line parser.
Splits on `\n`, iterates lines, tries each block type in priority order
(plugins first, then HR, header, code block, block math, blockquote, list,
footnote, details, table, paragraph). Uses `_ParseResult` with `linesConsumed`.

```dart
// block_parser.dart:54-56 -- Plugin priority
if (_plugins != null) {
  final pluginResult = _tryParseWithPlugins(line, lines, i);
  if (pluginResult != null) { ... }
}
```

**`lib/src/parser/inline_parser.dart`** - Character-by-character scanner.
Tries: plugins, image, footnote ref, link, inline code, inline math,
strikethrough, bold, italic, then plain text. Merges consecutive TextNodes.

**`lib/src/parser/parser_plugin.dart`** - Plugin system with
`ParserPluginRegistry`, `BlockParserPlugin`, `InlineParserPlugin`. Supports
priority ordering, trigger characters for inline plugins, register/unregister.

### Renderer Layer

**`lib/src/renderer/markdown_renderer.dart`** - Takes AST nodes, looks up
builder per node type from `BuilderRegistry`, builds Flutter widgets. Renders
block nodes into a `Column` with spacing. Inline rendering builds `RichText`
with `TextSpan`/`WidgetSpan`.

```dart
// markdown_renderer.dart:256-270 -- Widget embedding via WidgetSpan
if (widget is Text) {
  return widget.textSpan ?? TextSpan(text: widget.data);
} else if (widget is RichText) {
  return widget.text;
}
return WidgetSpan(
  alignment: PlaceholderAlignment.middle,
  child: widget,
);
```

**`lib/src/renderer/widget_builder.dart`** - `MarkdownWidgetBuilder` base class
with `build()` and `canBuild()`. `BuilderRegistry` maps node type strings to
builders. `MarkdownRenderContext` carries `onTapLink`, `imageBuilder`,
`codeBuilder`, `inlineRenderer`, `blockRenderer`, `styleSheet`.

### AI-Specific Features

**Thinking blocks** (`thinking_plugin.dart` + `thinking_builder.dart`):
Parses `<thinking>...</thinking>` and `<think>...</think>` tags. Renders as
a collapsible container with animation.

**Artifact blocks** (`artifact_plugin.dart` + `artifact_builder.dart`):
Parses `<artifact identifier="..." type="..." ...>...</artifact>`. Supports
code, document, HTML, SVG, component, mermaid, custom types. Renders with
header, copy button, type label.

**Tool calls** (`tool_call_plugin.dart` + `tool_call_builder.dart`):
Parses `<tool_use>...</tool_use>` with `<tool_name>`, `<tool_id>`, `<input>`.
Renders with status indicators (running, completed, failed, cancelled, pending).

### Mermaid Subsystem

A complete native Dart Mermaid renderer (no WebView). Supports flowcharts,
sequence diagrams, pie charts, Gantt charts, timelines, kanban boards. Class
and state diagrams are stubbed but not implemented.

---

## Scoring Table

| # | Axis | Score | Notes |
|---|------|:-----:|-------|
| 1 | Native Widget Embedding | 7 | Possible via plugin+builder+WidgetSpan but requires boilerplate; no built-in widget syntax |
| 2 | Interactive Elements | 8 | `onTapLink` callback passes URL string; enhanced link builder has hover/animation; no built-in modal support |
| 3 | Extensibility | 9 | Robust plugin system (block+inline), builder registry, priority ordering; 8 example plugins included |
| 4 | AI Streaming | 3 | Full re-parse/re-render on every chunk; 50ms throttle is a band-aid; no incremental AST updates |
| 5 | Architecture & Design | 8 | Clean parser/renderer separation; AST-based; `MarkdownConfig` is accepted but UNUSED in parsing logic |
| 6 | Code Quality | 6 | Excellent documentation; but `parseAsync` is fake-async, `errorBuilder` unused, `MarkdownConfig` dead code, stream errors silently swallowed |
| 7 | API Compatibility | 5 | Similar concepts but different API; `MarkdownBody`->`SmoothMarkdown`, custom parser (not `package:markdown`), different builder interface |
| 8 | Performance | 5 | Good static: LRU cache + RepaintBoundary; bad streaming: full re-parse per chunk, no virtualization in Column |
| 9 | Feature Completeness | 8 | GFM tables, task lists, LaTeX, Mermaid, footnotes, details/summary, AI-specific blocks; missing: autolinks (declared not implemented), HTML parsing |
| 10 | Accessibility | 2 | No `Semantics` widgets anywhere in builders; no screen reader support for headers, links, images; no selection support beyond `SelectableText` in code blocks |

**Weighted Total: 61/100**

---

## Detailed Axis Analysis

### 1. Native Widget Embedding (7/10)

The architecture supports rendering arbitrary Flutter widgets inside markdown
through the builder+plugin system. The `MarkdownRenderer.renderInline()` method
wraps non-text widgets in `WidgetSpan`:

```dart
// markdown_renderer.dart:267-269
return WidgetSpan(
  alignment: PlaceholderAlignment.middle,
  child: widget,
);
```

However, there is no built-in markdown syntax like `@widget(ButtonWidget)` --
you must implement custom syntax, a parser plugin, a custom AST node, and a
builder for each widget type. The `ArtifactBuilder` and `ToolCallBuilder` are
good examples of complex widget embedding.

**Soliplex impact:** We can embed interactive cards, buttons, etc., but each
requires a plugin+builder pair. Medium implementation effort per widget type.

### 2. Interactive Elements (8/10)

Links support custom tap handling via `onTapLink` callback:

```dart
// smooth_markdown.dart:298
final void Function(String url)? onTapLink;
```

The `EnhancedLinkBuilder` wraps links in `GestureDetector` with hover
animations:

```dart
// enhanced_link_builder.dart:103-106
child: GestureDetector(
  onTap: () {
    widget.context.onTapLink?.call(widget.url);
  },
```

The callback only provides the URL string -- we would need to parse the URL
in our handler to decide whether to open a modal, navigate, or launch
externally. This is adequate but not as rich as passing the full `LinkNode`
with title and children.

**Soliplex impact:** Our modal-on-click requirement is achievable by inspecting
the URL in the callback. We could also override the link builder entirely for
richer behavior.

### 3. Extensibility (9/10)

The plugin system is the strongest feature of this package:

- `BlockParserPlugin`: `canParse(line, lines, index)` + `parse(lines, startIndex)`
- `InlineParserPlugin`: `triggerCharacter` + `canParse(text, index)` + `parse(text, startIndex)`
- `ParserPluginRegistry`: Priority-sorted, register/unregister, auto-type-detection
- `BuilderRegistry`: String-keyed map of `MarkdownWidgetBuilder` instances

Eight example plugins ship with the package: thinking, artifact, tool_call,
admonition, emoji, hashtag, mention, mermaid. These serve as templates.

**Soliplex impact:** Excellent for our custom extension needs. We could
implement AG-UI tool rendering, custom citation syntax, and interactive
elements as plugins.

### 4. AI Streaming (3/10)

**Critical weakness.** The `StreamMarkdown` implementation:

1. Accumulates ALL chunks into a `StringBuffer`
2. On each update, converts the entire buffer to a string
3. Passes the full string to `SmoothMarkdown` (which re-parses everything)
4. Cache is explicitly disabled (`enableCache: false`)

```dart
// stream_markdown.dart:349-359
return RepaintBoundary(
  child: SmoothMarkdown(
    data: _currentText,
    enableCache: false, // Disable cache for constantly changing content
  ),
);
```

The 50ms throttle (`_throttleDuration`) batches rapid updates but does not
address the O(n) re-parse on every update where n is the total accumulated
content length.

**What it lacks:**

- No incremental/delta parsing (only append new nodes for new content)
- No AST diffing (detect which nodes changed)
- No partial widget tree rebuilds
- `parseAsync` is fake: `Future.value(parse(markdown))` (sync wrapped)

**Soliplex impact:** For a 2000-token AI response arriving 20 tokens/sec over
100 updates, the parser re-processes increasingly large content. Late in the
response, each update parses ~2000 tokens. This will cause frame drops.

### 5. Architecture & Design (8/10)

Clean three-layer architecture:

- **Parser layer**: AST nodes, block/inline parsers, plugin system, cache
- **Renderer layer**: Node-to-widget mapping via builder registry
- **Widget layer**: Public API widgets (SmoothMarkdown, StreamMarkdown)

**Flaw: `MarkdownConfig` is dead code.** The config is accepted as a parameter
on both `SmoothMarkdown` and `StreamMarkdown` but is NEVER read during parsing
or rendering. The `enableCodeHighlight`, `enableTables`, `enableLatex`, etc.
flags have zero effect:

```dart
// smooth_markdown.dart:538 -- parser ignores config
final parser = MarkdownParser(plugins: plugins);
// MarkdownConfig is not passed to the parser
```

### 6. Code Quality (6/10)

**Strengths:**

- Extensive dartdoc comments on all public APIs
- Consistent use of `const` constructors and `final` fields
- Clean naming conventions
- `copyWith()` and `toJson()` on all AST nodes

**Weaknesses:**

1. **`parseAsync` is fake-async:**

```dart
// markdown_parser.dart:72-74
Future<List<MarkdownNode>> parseAsync(String markdown) async {
  return Future.value(parse(markdown));
}
```

1. **Stream errors are silently swallowed:**

```dart
// stream_markdown.dart:314-316
onError: (error) {
  // Error will be handled by StreamBuilder  <-- misleading comment
},
```

1. **`errorBuilder` parameter is accepted but unused** in StreamMarkdown

1. **Stream subscription is never cancelled** - `_listenToStream()` creates
a subscription but it is not stored in a field or cancelled in `dispose()`:

```dart
// stream_markdown.dart:290
widget.stream.listen(  // No variable captures the StreamSubscription
```

1. **`didUpdateWidget` leaks subscriptions** - When the stream changes,
`_listenToStream()` is called again without cancelling the previous subscription

1. **Header inline parsing is a no-op:**

```dart
// markdown_parser.dart:96-109
HeaderNode _processHeader(HeaderNode node) {
  final inlineNodes = _inlineParser.parse(node.content);
  if (inlineNodes.length == 1 && inlineNodes[0] is TextNode) {
    return node;
  }
  // For now, we keep the header content as-is
  return node;  // <-- Inline formatting in headers is NEVER applied
}
```

Wait - but `BlockParser._parseHeader()` does parse inline children and stores
them in `HeaderNode.children`. The `MarkdownParser._processHeader()` then
re-parses but discards the result. The block parser already handles this
correctly at `block_parser.dart:150-167`.

### 7. API Compatibility (5/10)

| flutter_markdown | flutter_smooth_markdown | Compatible? |
|-----------------|------------------------|:-----------:|
| `MarkdownBody` | `SmoothMarkdown` | Concept match, different API |
| `MarkdownStyleSheet` | `MarkdownStyleSheet` | Same name but different fields |
| `MarkdownElementBuilder` | `MarkdownWidgetBuilder` | Different interface |
| `extensionSet` | `plugins` | Different system entirely |
| `onTapLink(text, href, title)` | `onTapLink(url)` | Fewer params |
| `builders` map | `builderRegistry` | Different registration |
| `package:markdown` AST | Custom AST | Incompatible |
| `selectable: true` | Not supported | Missing |
| `shrinkWrap` | Not available | Missing |

**Soliplex impact:** Not a drop-in replacement. Migration requires rewriting
our `CodeBlockBuilder`, adapting `MarkdownStyleSheet`, and changing
`onTapLink` handlers. Our existing `package:markdown` extensions would not
carry over.

### 8. Performance (5/10)

**Static content performance is good:**

- LRU parse cache (`MarkdownParseCache`, maxSize: 100)
- `RepaintBoundary` wrapping (optional, default on)
- Stateless builders for most node types

**Streaming performance is poor:**

- Full re-parse per update
- Cache disabled during streaming
- No widget tree diffing
- No lazy rendering / virtualization

**Renderer produces a flat Column:**

```dart
// markdown_renderer.dart:210-214
return Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: _addSpacing(widgets),
);
```

For a 500-element markdown document, this creates a Column with 999 children
(500 widgets + 499 SizedBox spacers). No `ListView.builder` or sliver-based
rendering.

### 9. Feature Completeness (8/10)

**Implemented:**

- Headers (H1-H6) with level validation
- Paragraphs, blockquotes, horizontal rules
- Ordered and unordered lists with task list support
- Tables with column alignment (left/center/right)
- Fenced code blocks with language detection
- Syntax highlighting via `flutter_highlight`
- Inline: bold, italic, strikethrough, inline code, links, images
- LaTeX: inline `$...$` and block `$$...$$` via `flutter_math_fork`
- Footnotes (references and definitions)
- Details/summary (HTML `<details>` blocks)
- Mermaid diagrams (flowchart, sequence, pie, gantt, timeline, kanban)
- AI-specific: thinking blocks, artifacts, tool calls
- Theme presets: light, dark, github, vscode, fromTheme, fromBrightness

**Not implemented:**

- Autolinks (declared in `MarkdownConfig.enableAutoLinks` but not implemented)
- HTML inline tags (declared in `MarkdownConfig.enableHtml` but not implemented)
- Class diagrams and state diagrams (stubbed in mermaid parser)
- Emoji shortcodes (plugin exists but builder not registered by default)
- `SelectionArea` wrapping (no built-in support)

### 10. Accessibility (2/10)

**Zero `Semantics` widgets in the entire renderer.** None of the 20+ builders
in `lib/src/renderer/builders/` use `Semantics`, `MergeSemantics`,
`ExcludeSemantics`, or any accessibility API.

- Headers render as styled `Text` -- no `Semantics(header: true)`
- Links render as `GestureDetector` -- no `Semantics(link: true, label: ...)`
- Images render without `Semantics(image: true, label: alt)`
- Tables have no semantic structure
- Code blocks have no semantic annotations
- The `EnhancedCodeBlockBuilder` copy button has no `Tooltip` or semantic label
  that would be announced by a screen reader

**Soliplex impact:** This is a production blocker. We would need to wrap or
override nearly every builder to add accessibility support.

---

## Claim Verification

| Claim | Verdict | Evidence |
|-------|---------|----------|
| AST-based parsing | **VERIFIED** | 21 typed node classes in `markdown_node.dart`; two-pass parser (block then inline) |
| Real-time streaming | **MISLEADING** | `StreamMarkdown` exists but re-parses entire content per chunk; documentation admits this |
| Mermaid diagrams | **VERIFIED** | Native Dart implementation with 7 parsers, 7 painters, 8 models, 3 layout engines |
| LaTeX support | **VERIFIED** | `InlineMathNode`/`BlockMathNode` parsed; rendered via `flutter_math_fork` |
| Plugin architecture | **VERIFIED** | Robust `ParserPluginRegistry` with block+inline plugins, priority ordering, 8 examples |
| Theme presets | **VERIFIED** | 6 factory constructors on `MarkdownStyleSheet`: light, dark, github, vscode, fromTheme, fromBrightness |

---

## Migration Path from flutter_markdown

### What maps directly

- `MarkdownBody(data: ...)` -> `SmoothMarkdown(data: ...)`
- `onTapLink: (text, href, title)` -> `onTapLink: (url)` (fewer params)
- `MarkdownStyleSheet(...)` -> `MarkdownStyleSheet(...)` (different fields)

### What requires rewriting

- Our `CodeBlockBuilder extends MarkdownElementBuilder` must become
  a `MarkdownWidgetBuilder` subclass
- Our `MarkdownStyleSheet` customization needs field-by-field remapping
- Our use of `SelectionArea` wrapping has no equivalent
- Our use of `package:markdown` extensions must be reimplemented as plugins

### What we lose

- `Semantics` support (flutter_markdown has some; this has none)
- `selectable` parameter
- `onTapLink` receiving text and title (only URL here)
- Battle-tested CommonMark compliance from `package:markdown`

### Estimated effort

- **Minimum viable migration:** 3-5 days (basic rendering, code blocks, styling)
- **Full feature parity:** 2-3 weeks (accessibility, streaming fixes, plugin porting)
- **Production ready:** 4-6 weeks (testing, performance tuning, edge cases)

---

## Soliplex-Specific Verdict

### Strengths for Soliplex

1. Plugin architecture aligns perfectly with our custom extension needs
2. AI-specific features (thinking, artifacts, tool calls) match our LLM chat use case
3. Mermaid and LaTeX support are features we want but lack today
4. Builder registry allows complete rendering customization
5. Parse cache improves performance for chat history scrolling

### Blockers for Soliplex

1. **Streaming performance is unacceptable** for token-by-token AI responses
2. **Zero accessibility** is a production blocker
3. **Stream subscription leak** in `StreamMarkdown` (no cancel on dispose/update)
4. **`MarkdownConfig` is dead code** -- feature flags do nothing
5. **Unverified publisher** with only 6 likes raises maintenance/trust concerns

### Recommendation: DO NOT ADOPT (as-is)

The package has a superior architecture and feature set compared to
`flutter_markdown`, but the streaming implementation and accessibility gaps
are critical blockers for Soliplex.

**If we wanted to adopt this package, we would need to fork and fix:**

1. Implement incremental streaming (delta parsing, AST append)
2. Add `Semantics` to all builders
3. Fix stream subscription lifecycle in `StreamMarkdown`
4. Wire `MarkdownConfig` to actually control parser behavior
5. Implement `parseAsync` with real isolate-based async parsing

This is estimated at 3-4 weeks of engineering work. Given the low community
adoption (6 likes), this effectively means maintaining a fork indefinitely.

**Alternative recommendation:** Stay on `flutter_markdown` and build our
custom extensions (LaTeX, Mermaid, AI blocks) as `MarkdownElementBuilder`
implementations, leveraging the more mature accessibility and CommonMark
compliance.
