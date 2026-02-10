# markdown_viewer v0.6.2 -- Claude Audit

**Auditor:** Claude Opus 4.6
**Date:** 2026-02-10
**Source:** <https://github.com/tagnote-app/markdown_viewer>
**pub.dev:** <https://pub.dev/packages/markdown_viewer>

---

## 1. Package Overview

| Field | Value |
|-------|-------|
| Version | 0.6.2 |
| Publisher | tagnote.app (verified) |
| Likes / Points / Downloads | 24 / 90 / 1.5k |
| License | BSD-3-Clause |
| Last Updated | May 2023 |
| Dart SDK | `>=2.19.4 <4.0.0` |
| Flutter SDK | `>=1.17.0` |
| Dependencies | `dart_markdown ^3.1.7`, Flutter SDK |
| Source LOC (lib/) | 2,790 lines across 29 files |
| Test LOC | 222 lines across 4 files |

`markdown_viewer` is a Flutter markdown rendering widget that uses
`dart_markdown` (a non-standard fork) instead of the `markdown` package used
by `flutter_markdown`. It features a builder-based architecture where each
markdown element type is handled by a dedicated `MarkdownElementBuilder`
subclass.

---

## 2. Architecture Analysis

### Rendering Pipeline

```text
Raw Markdown String
        |
        v
+---------------------------+
| dart_markdown.Markdown    |  External package
| .parse(data)              |  Produces md.Node AST
+---------------------------+
        |
        v
+---------------------------+
| AstTransformer            |  transformer.dart
| .transform(nodes)         |  Normalizes type names,
|                           |  merges adjacent text,
|                           |  collects footnotes
+---------------------------+
        |
        v
+---------------------------+
| MarkdownRenderer          |  renderer.dart
| implements NodeVisitor    |  Visitor pattern over
|                           |  MarkdownElement/Text AST
|  +-----------------------+|
|  | Builder Registry      ||  Map<String, Builder>
|  | (12 default builders) ||
|  +-----------------------+|
+---------------------------+
        |
        v
+---------------------------+
| Widget Compression        |  merge_rich_text.dart
| mergeRichText()           |  Combines adjacent
|                           |  RichText into one
+---------------------------+
        |
        v
+---------------------------+
| MarkdownViewer Widget     |  widget.dart
| Column / single child     |  Wraps in SelectionArea
+---------------------------+
```

### Key Architectural Decisions

1. **Two-phase AST:** The `dart_markdown` AST is first transformed into an
   internal `MarkdownElement`/`MarkdownText` tree before rendering. This
   decouples the parser from the renderer but adds an O(N) pass.

2. **Builder registry:** Each element type maps to a `MarkdownElementBuilder`
   via `matchTypes`. Custom builders override defaults when registered later
   in the list (renderer.dart:140).

3. **RichText merging:** Adjacent `RichText` widgets are compressed into a
   single `RichText` with merged `TextSpan` children
   (merge_rich_text.dart:3-114). This reduces the widget tree size.

4. **Inline widget restriction:** The renderer asserts that non-block widgets
   must be `RichText`, `Text`, or `DefaultTextStyle` (renderer.dart:326-339).
   This is a hard architectural limitation.

---

## 3. Source Code Walkthrough

### Entry Point: `lib/markdown_viewer.dart`

Barrel file exporting: `ast.dart`, `builder.dart`, `definition.dart`,
`markdown_tree_element.dart`, `renderer.dart`, `style.dart`, `widget.dart`.

### Widget: `lib/src/widget.dart` (164 lines)

`MarkdownViewer` is a `StatefulWidget`. On every `build()`:

- Creates a new `md.Markdown` parser with feature flags (widget.dart:98-111)
- Parses the raw string: `markdown.parse(widget.data)` (widget.dart:130)
- Wraps parse in try/catch -- on failure, renders entire text as paragraph
  (widget.dart:129-145)
- Creates `MarkdownRenderer` with all callbacks and style (widget.dart:113-126)
- Renders AST to widget list (widget.dart:147)
- Returns `Column` for multiple children, single widget, or `SizedBox.shrink`
  (widget.dart:150-162)
- Wraps in `SelectionArea` unless `selectable == false` (widget.dart:84-95)

**Notable:** Parser and renderer are recreated on every build. No caching.

### AST: `lib/src/ast.dart` (101 lines)

Three classes:

- `MarkdownNode` -- abstract base with `position`, `accept()`, `toMap()`
- `MarkdownElement` -- has `type`, `isBlock`, `children`, `attributes`
- `MarkdownText` -- leaf node with `text` string
- `SiblingPosition` -- mutable position tracker (`index`, `total`)

`SiblingPosition` is mutable, which is unusual for AST nodes. Positions are
updated in-place by `AstTransformer._updatePosition()`.

### Transformer: `lib/src/transformer.dart` (125 lines)

Converts `md.Node` tree to `MarkdownElement`/`MarkdownText` tree.

- Type normalization map (transformer.dart:8-16): `atxHeading` -> `headline`,
  `fencedCodeBlock` -> `codeBlock`, `autolinkExtension` -> `link`, etc.
- Merges adjacent `md.Text` nodes into single `MarkdownText` using
  `StringBuffer` (transformer.dart:43-50)
- Skips `blankLine`, `linkReferenceDefinition`; collects `footnoteReference`
  nodes separately (transformer.dart:56-66)
- Inlines emoji text content (transformer.dart:68-70)
- Appends footnote reference block at end if any exist (transformer.dart:30-33)

### Renderer: `lib/src/renderer.dart` (340 lines)

Core rendering engine. Implements the Visitor pattern.

**Constructor** (renderer.dart:28-145):

- Creates 12 default builders (Headline, SimpleInlines, ThematicBreak,
  Paragraph, CodeSpan, Link, Table, Image, CodeBlock, Blockquote, List,
  Footnote)
- Registers builders by iterating `matchTypes`, custom builders override
  defaults (renderer.dart:140-144)

**`render()`** (renderer.dart:163-180):

- Clears internal state
- Creates root `_TreeElement`
- Transforms AST via `AstTransformer().transform(nodes)`
- Visits each root-level node
- Returns children of root tree element

**`visitElementBefore()`** (renderer.dart:183-207):

- Looks up builder by element type (asserts existence)
- Calls `builder.init(element)`
- Sets `parentStyle` on builder
- Handles `replaceLineEndings` flag
- Creates gesture recognizers
- Pushes new `_TreeElement` onto tree stack

**`visitText()`** (renderer.dart:210-233):

- Replaces newlines with spaces unless `_keepLineEndingsWhen` is set
- Calls `builder.buildText()` to create TextSpan
- Applies gesture recognizer from stack
- Wraps in `RichText` via `createRichText()`

**`visitElementAfter()`** (renderer.dart:236-285):

- Pops tree element
- Calls `builder.createText()` for non-text-child elements
- Compresses widgets via `compressWidgets()` (mergeRichText)
- Calls `builder.buildWidget()` to create final widget
- Adds block spacing `SizedBox` between block elements
- Handles `InlineWraper` by flattening children into parent
- Asserts inline widget type restriction (renderer.dart:272-273)

**`_checkInlineWidget()`** (renderer.dart:326-339):

- **CRITICAL LIMITATION:** Only allows `RichText`, `Text`, `DefaultTextStyle`
  as inline widgets. Any custom inline widget (Button, Chip, etc.) will trigger
  an assertion failure in debug and a null dereference path in release.

### Base Builder: `lib/src/builders/builder.dart` (145 lines)

`MarkdownElementBuilder` abstract class:

- `matchTypes` -- list of element type strings this builder handles
- `textStyle` / `textStyleMap` -- styling for single or multiple types
- `parentStyle` -- set by renderer before building
- `register(renderer)` -- stores renderer reference
- `init(element)` -- called before children are visited
- `gestureRecognizer(element)` -- returns null by default
- `replaceLineEndings(type)` -- returns true (replace `\n` with space)
- `buildTextStyle(element, defaultStyle)` -- merges parent + element styles
- `buildText(text, parent)` -- creates `TextSpan` with parent style
- `textAlign(parent)` -- returns null (use default)
- `createText(element, parentStyle)` -- returns null by default
- `isBlock(element)` -- delegates to `element.isBlock`
- `blockPadding(element, parent)` -- returns `EdgeInsets.zero`
- `buildWidget(element, parent)` -- default: Column for blocks, InlineWraper
  for inlines; applies blockPadding

### Individual Builders (Highlights)

**CodeBlockBuilder** (code_block_builder.dart, 114 lines):

- `replaceLineEndings` returns false (preserves newlines)
- `buildText()` applies monospace font, calls `highlightBuilder` if provided
- `buildWidget()` wraps in `Container` + `Stack` with `CopyButton` overlay
- Horizontal scroll via `SingleChildScrollView`

**LinkBuilder** (link_builder.dart, 38 lines):

- Default blue color `Color(0xff2196f3)`
- Creates `TapGestureRecognizer` that calls `onTapLink(href, title)`
- Callback receives `destination` and `title` from attributes
- Supports modal/custom handling (not just URL launch)

**ImageBuilder** (image_builder.dart, 137 lines):

- **SECURITY RISK:** Imports `dart:io` and falls back to `Image.file()`
  for non-http/data/resource URIs (image_builder.dart:109)
- **WEB INCOMPATIBLE:** `dart:io` import breaks web builds
- Supports optional image size parsing from URL hash
  (`#widthxheight` suffix)
- Custom `imageBuilder` callback for full control

**TableBuilder** (table_bilder.dart, 134 lines):

- Note: filename has typo ("bilder" instead of "builder")
- Handles `table`, `tableHead`, `tableRow`, `tableBody`, cell types
- Uses Flutter `Table` widget with `IntrinsicColumnWidth` default
- Horizontal scroll support via `SingleChildScrollView` + `Scrollbar`
- Row decoration alternating support

**ListBuilder** (list_builder.dart, 161 lines):

- Handles ordered/bullet lists and task list items
- Variable `_listStrack` has typo (should be `_listStack`)
- Custom marker builder and checkbox builder callbacks
- Uses `Row` with `ConstrainedBox` for marker alignment

### Helpers

**InlineWraper** (inline_wraper.dart, 24 lines):

- Note: filename has typo ("wraper" instead of "wrapper")
- Fake `Widget` subclass used as a marker to flatten inline children
- Creates a dummy `Element` that does nothing -- hacky but functional
- **CONCERN:** Directly subclasses `Widget` and creates a non-functional
  `Element`. This could break with Flutter framework changes.

**merge_rich_text.dart** (114 lines):

- Merges adjacent `RichText` widgets into single `RichText` with combined
  `TextSpan` children
- Skips merging when `WidgetSpan` or `fontFeatures` are present
- Uses `Wrap` when multiple non-mergeable inline widgets exist
- `_mergeSimilarTextSpans()` combines spans with identical styles

**is_dark_mode.dart** (4 lines):

- Simple `Theme.of(context).brightness == Brightness.dark` check
- Returns false when context is null

**parse_block_padding.dart** (39 lines):

- Strips top padding from first child, bottom from last child
- Prevents extra spacing at boundaries of parent containers

### Style: `lib/src/style.dart` (119 lines)

`MarkdownStyle` -- flat class with 40+ nullable `TextStyle?` fields plus
`EdgeInsets?`, `BoxDecoration?`, `TableBorder?` fields. No factory constructor,
no `fromTheme()`, no `copyWith()`, no `merge()`.

### Selection: `lib/src/selection/` (2 files, unused)

`DesktopTextSelectionToolbarCustom` and `MobileTextSelectionToolbar` --
custom selection toolbar implementations that are **never referenced** by the
main widget or renderer. Dead code.

### Definitions: `lib/src/definition.dart` (68 lines)

Type aliases for `dart_markdown` types (convenience re-exports) plus callback
typedefs: `MarkdownTapLinkCallback`, `MarkdownListItemMarkerBuilder`,
`MarkdownCheckboxBuilder`, `MarkdownHighlightBuilder`, `MarkdownImageBuilder`,
`CopyIconBuilder`.

### Extensions: `lib/src/extensions.dart` (237 lines)

Debug/inspection extensions on `Widget`, `TextSpan`, `TableRow`, `Decoration`,
`BoxConstraints`, `BorderSide`, `TextStyle` -- all produce `Map` / JSON for
test assertions. Also generic `List` and `Map` extensions (`addIfAbsent`,
`addIfNotNull`, `addIfTrue`).

**Note:** `BoxConstraintsExtensions.toMap()` has a bug at line 155:
`'maxWidth': maxHeight` and `'maxHeight': maxWidth` are swapped.

---

## 4. Scoring Table

| # | Criteria | Score | Justification |
|---|----------|:-----:|---------------|
| 1 | **Native Widget Embedding** | 5/10 | Block-level custom widgets work well via `buildWidget()`. Inline widgets are blocked by `_checkInlineWidget()` assertion (renderer.dart:326-339). Cannot embed buttons/chips inside a paragraph without forking. |
| 2 | **Interactive Elements** | 7/10 | `onTapLink` callback provides href + title, supporting modal opening. Custom builders can add gesture recognizers via `gestureRecognizer()`. No built-in support for tap targets on non-link elements. |
| 3 | **Extensibility** | 7/10 | Clean `syntaxExtensions` + `elementBuilders` API. Custom syntax must use `dart_markdown` types (not standard `markdown` package). Builder override mechanism is simple but effective. |
| 4 | **AI Streaming** | 3/10 | Full parse + transform + render on every build. No incremental rendering, no diff-based updates, no partial AST reuse. Parser and renderer recreated each frame. For 20-50 token/sec streaming, this is expensive. |
| 5 | **Architecture & Design** | 6/10 | Clean separation of concerns (parse -> transform -> render -> compress). Builder pattern is well-structured. However: mutable AST positions, two-pass AST, `InlineWraper` hack, and dead selection code reduce the score. |
| 6 | **Code Quality** | 5/10 | Multiple typos in filenames (`table_bilder.dart`, `inline_wraper.dart`) and variables (`_listStrack`). Swapped maxWidth/maxHeight in BoxConstraints extension. Hardcoded colors throughout builders instead of theme derivation. Uses deprecated `bodyText2` API (renderer.dart:50). |
| 7 | **API Compatibility** | 4/10 | Significantly different from `flutter_markdown`. Different widget name (`MarkdownViewer` vs `MarkdownBody`), different style class, different builder interface, different underlying parser (`dart_markdown` vs `markdown`). Migration requires rewriting all custom builders. |
| 8 | **Performance** | 5/10 | RichText merging is a positive optimization. However: full rebuild on every frame, no widget caching, double AST pass, no `const` constructors where possible. `Column` at top level prevents virtualization of long documents. |
| 9 | **Feature Completeness** | 8/10 | GFM tables, code blocks with syntax highlighting, images, task lists, footnotes, subscript/superscript, kbd, strikethrough, autolink, emoji. HTML rendering intentionally disabled. |
| 10 | **Accessibility** | 3/10 | No explicit `Semantics` widgets. Image alt text not used in default builder. RichText merging can strip semantic labels. Custom selection toolbars exist but are dead code. No ARIA-like annotations. |
| | **Total** | **53/100** | |

---

## 5. Critical Issues

### P0 - Blockers

1. **`dart:io` import in image_builder.dart breaks web builds.**
   `Image.file(File.fromUri(uri))` at line 109 uses `dart:io.File` which is
   unavailable on web. Soliplex runs on web -- this is a build-time failure
   unless the image builder is overridden or the file is forked.

2. **Deprecated API: `bodyText2`.**
   `renderer.dart:50` uses `Theme.of(context).textTheme.bodyText2` which is
   deprecated in Flutter 3.x/Material 3. Should be `bodyMedium`.

3. **No incremental rendering for AI streaming.**
   Every token update triggers full parse -> transform -> render. For a chat
   app streaming 20-50 tokens/sec, this creates O(N^2) cumulative work as
   messages grow.

### P1 - High Severity

1. **Inline widget restriction prevents custom interactive elements.**
   `_checkInlineWidget()` only allows `RichText`, `Text`,
   `DefaultTextStyle`. Any inline button/chip/tooltip will assertion-fail in
   debug mode. In release mode, the assertion is stripped but the constraint
   still shapes the architecture.

2. **Release-mode crash on unmapped element types.**
   `renderer.dart:186` asserts builder existence, then line 188 uses `!`
   operator: `_builders[type]!`. If a custom syntax extension emits an
   unmapped type, this throws `Null check operator used on a null value` in
   release.

3. **Security: local file access via image builder.**
   Untrusted markdown with relative image paths will attempt to read local
   filesystem via `Image.file()`. No URI scheme allowlist.

### P2 - Medium Severity

1. **Stale maintenance** -- last commit May 2023, 2+ years old.
2. **BoxConstraints toMap() bug** -- maxWidth and maxHeight are swapped
   (extensions.dart:155).
3. **Dead code** -- selection toolbar files are never used.
4. **Mutable SiblingPosition** -- AST nodes have mutable position fields,
    making the tree non-idempotent across transforms.

### P3 - Low Severity

1. **Typos in filenames:** `table_bilder.dart`, `inline_wraper.dart`.
2. **Typo in variable:** `_listStrack` (list_builder.dart:36).
3. **Hardcoded colors** throughout builders instead of theme-derived defaults.
4. **No `copyWith()` / `merge()` on MarkdownStyle** -- inconvenient for
    theme integration.

---

## 6. Migration Path from flutter_markdown

### Step 1: Dependency Swap

```yaml
# Remove
flutter_markdown: ^0.7.4+1

# Add (if using pub.dev version)
markdown_viewer: ^0.6.2

# Or add as git dependency / forked copy
```

### Step 2: Widget Replacement

```dart
// Before (flutter_markdown)
MarkdownBody(
  data: markdownText,
  styleSheet: markdownStyleSheet,
  builders: {'code': CodeBlockBuilder()},
  onTapLink: (text, href, title) => handleLink(href),
)

// After (markdown_viewer)
MarkdownViewer(
  markdownText,
  styleSheet: markdownStyle,        // Different class
  elementBuilders: [MyCodeBuilder()], // Different builder API
  onTapLink: (href, title) => handleLink(href),
  highlightBuilder: (text, lang, info) => highlightCode(text, lang),
)
```

### Step 3: Style Migration

`MarkdownStyleSheet` fields map approximately to `MarkdownStyle` fields but
names differ. There is no `MarkdownStyle.fromTheme()` factory -- all values
must be provided explicitly or left null for hardcoded defaults.

Key mappings:

- `h1` -> `headline1`
- `p` -> `paragraph`
- `code` -> `codeSpan`
- `codeblockDecoration` -> `codeblockDecoration` (same name)
- `tableHead` -> `tableHead`
- No `fromTheme()` or Material 3 integration

### Step 4: Builder Migration

```dart
// flutter_markdown builder
class CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(context, text, preferred, style) { ... }
}

// markdown_viewer builder
class MyCodeBlockBuilder extends MarkdownElementBuilder {
  @override
  List<String> get matchTypes => ['codeBlock'];

  @override
  Widget? buildWidget(MarkdownTreeElement element, MarkdownTreeElement parent) {
    // Access element.children, element.attributes, element.style
    ...
  }
}
```

### Step 5: Syntax Highlighting

The `highlightBuilder` callback replaces custom code block builders for
syntax highlighting. It receives `(String text, String? language, String? infoString)` and returns `List<TextSpan>`.

### Step 6: Handle Image Builder

Must override `imageBuilder` to avoid `dart:io` dependency on web:

```dart
MarkdownViewer(
  data,
  imageBuilder: (uri, info) => Image.network(uri.toString()),
)
```

### Estimated Migration Effort

- Small codebase (1-2 custom builders): 2-4 hours
- Medium codebase (Soliplex-scale with theme integration): 1-2 days
- With streaming optimization fork: 1-2 weeks

---

## 7. Verdict

### NOT RECOMMENDED for direct use from pub.dev

**Rationale:**

The `markdown_viewer` package has a reasonably clean builder architecture and
good feature coverage, but it fails on several critical requirements for
Soliplex:

1. **AI streaming performance is poor.** Full parse-transform-render on every
   token is unacceptable for real-time chat. There is no incremental rendering
   path, and adding one would require fundamental architectural changes.

2. **Web builds are broken** due to `dart:io` import in the default image
   builder.

3. **Inline widget embedding is architecturally blocked**, preventing the
   interactive inline elements Soliplex needs (citation chips, action buttons
   inside text).

4. **The package is abandoned** (2+ years without updates) and uses deprecated
   Flutter APIs.

5. **The `dart_markdown` dependency** locks you into a non-standard parser
   ecosystem with uncertain long-term support.

### Conditional Consideration

If Soliplex were to **fork** the package, the architecture is a reasonable
starting point for a custom markdown renderer. The builder pattern is cleaner
than `flutter_markdown`'s approach, and block-level widget embedding works
well. However, the fork would require:

- Fixing `dart:io` import for web compatibility
- Removing `_checkInlineWidget` restriction
- Adding incremental rendering for streaming
- Replacing deprecated APIs
- Adding `MarkdownStyle.fromTheme()` for Material 3 integration
- Adding proper accessibility semantics

This represents significant investment (estimated 2-4 weeks) that may be
better spent on alternatives like `flutter_markdown` with custom extensions,
`markdown_widget`, or a purpose-built streaming markdown renderer.

---

## Appendix: File Inventory

| File | Lines | Role |
|------|------:|------|
| `lib/markdown_viewer.dart` | 10 | Barrel export |
| `lib/src/ast.dart` | 101 | Internal AST nodes |
| `lib/src/definition.dart` | 68 | Typedefs and enums |
| `lib/src/extensions.dart` | 237 | Debug extensions |
| `lib/src/renderer.dart` | 340 | Core rendering visitor |
| `lib/src/style.dart` | 119 | Style configuration |
| `lib/src/transformer.dart` | 125 | AST transformer |
| `lib/src/widget.dart` | 164 | Entry point widget |
| `lib/src/builders/builder.dart` | 145 | Base builder class |
| `lib/src/builders/blockquote_builder.dart` | 57 | Blockquote |
| `lib/src/builders/code_block_builder.dart` | 114 | Code blocks |
| `lib/src/builders/code_span_builder.dart` | 49 | Inline code |
| `lib/src/builders/footnote_builder.dart` | 49 | Footnotes |
| `lib/src/builders/headline_builder.dart` | 61 | Headings |
| `lib/src/builders/image_builder.dart` | 137 | Images |
| `lib/src/builders/link_builder.dart` | 38 | Links |
| `lib/src/builders/list_builder.dart` | 161 | Lists |
| `lib/src/builders/paragraph_builder.dart` | 27 | Paragraphs |
| `lib/src/builders/simple_inlines_builder.dart` | 65 | Bold/italic/etc |
| `lib/src/builders/table_bilder.dart` | 134 | Tables |
| `lib/src/builders/thematic_break_builder.dart` | 28 | HR rules |
| `lib/src/helpers/inline_wraper.dart` | 24 | Inline hack |
| `lib/src/helpers/is_dark_mode.dart` | 4 | Dark mode check |
| `lib/src/helpers/merge_rich_text.dart` | 114 | Text merging |
| `lib/src/helpers/parse_block_padding.dart` | 39 | Padding logic |
| `lib/src/models/markdown_tree_element.dart` | 37 | Tree element model |
| `lib/src/selection/desktop_text_selection_toolbar.dart` | 190 | Unused |
| `lib/src/selection/mobile_text_selection_toolbar.dart` | 101 | Unused |
| `lib/src/widgets/copy_button.dart` | 67 | Code copy button |
