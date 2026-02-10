# Audit Report: `flutter_markdown_plus` v1.0.7

**Auditor:** Claude Opus 4.6
**Date:** 2026-02-10
**Package:** [flutter_markdown_plus](https://pub.dev/packages/flutter_markdown_plus) v1.0.7
**Publisher:** foresightmobile.com
**License:** BSD-3-Clause
**Pub points:** 160 | **Likes:** 95 | **Downloads:** ~129k
**Repository:** <https://github.com/foresightmobile/flutter_markdown_plus>
**Dart SDK:** ^3.4.0 | **Flutter:** >=3.27.1

---

## Executive Summary

`flutter_markdown_plus` is a direct continuation of Google's discontinued `flutter_markdown`
package. The source code is nearly identical to the upstream `flutter_markdown ^0.7.x` that
Soliplex currently uses. This makes it an almost zero-effort **drop-in replacement** from an
API perspective.

However, the package inherits all of the architectural limitations of the original: namely,
**full re-parse and full widget-tree rebuild on every data change**, which is a significant
concern for AI streaming in Soliplex chat bubbles.

**Overall Weighted Score: 6.3 / 10**

---

## Package Metadata

| Field | Value |
|---|---|
| Version | 1.0.7 |
| Publisher | foresightmobile.com |
| Likes | 95 |
| Pub Points | 160 |
| Downloads | ~129k |
| License | BSD-3-Clause |
| Dart SDK | ^3.4.0 |
| Flutter | >=3.27.1 |
| Dependencies | `flutter`, `markdown ^7.3.0`, `meta ^1.16.0`, `path ^1.9.1` |
| Source files | 6 (lib/) |
| Test files | 26 |

---

## Architecture Diagram

```text
+--------------------------------------------------------------------+
|                       Soliplex Chat Bubble                          |
|                    (SelectionArea wrapper)                          |
+--------------------------------------------------------------------+
        |
        | data: String (markdown text, updated per token)
        v
+--------------------------------------------------------------------+
|  MarkdownBody (widget.dart:445)                                    |
|    - StatefulWidget: _MarkdownWidgetState                          |
|    - Config: styleSheet, builders, extensionSet, ...               |
+--------------------------------------------------------------------+
        |
        | didUpdateWidget -> _parseMarkdown() (widget.dart:361)
        v
+--------------------------------------------------------------------+
|  md.Document (markdown package)                                    |
|    - LineSplitter -> parseLines -> AST nodes                       |
|    - extensionSet: gitHubFlavored (default)                        |
+--------------------------------------------------------------------+
        |
        | List<md.Node> (Abstract Syntax Tree)
        v
+--------------------------------------------------------------------+
|  MarkdownBuilder (builder.dart:101)                                |
|    implements md.NodeVisitor                                       |
|    - visitElementBefore / visitText / visitElementAfter            |
|    - Delegates: MarkdownBuilderDelegate                            |
|    - Custom: builders Map<String, MarkdownElementBuilder>          |
|    - Custom: paddingBuilders Map<String, MarkdownPaddingBuilder>   |
+--------------------------------------------------------------------+
        |
        | List<Widget>
        v
+--------------------------------------------------------------------+
|  Widget Tree (Column)                                              |
|    +-- Text.rich / SelectableText.rich (paragraphs, headings)      |
|    +-- SizedBox (block spacing)                                    |
|    +-- Container > Scrollbar > SingleChildScrollView (code blocks) |
|    +-- DecoratedBox > Padding (blockquotes)                        |
|    +-- Table / ClipRRect (tables)                                  |
|    +-- Row > SizedBox + Flexible (list items)                      |
|    +-- Image.network / Image.file / Image.asset (images)           |
|    +-- [Custom builder widgets]                                    |
+--------------------------------------------------------------------+

Platform Layer:
+------------------------------+    +------------------------------+
|  _functions_io.dart          |    |  _functions_web.dart         |
|  - kDefaultImageBuilder      |    |  - kDefaultImageBuilder      |
|  - kFallbackStyle            |    |  - kFallbackStyle            |
|  (uses dart:io, File)        |    |  (uses dart:js_interop)      |
+------------------------------+    +------------------------------+
```

---

## Source Code Walkthrough

### 1. Entry Point: `lib/flutter_markdown_plus.dart`

Minimal barrel file that re-exports the three modules:

```dart
// lib/flutter_markdown_plus.dart:8-10
export 'src/builder.dart';
export 'src/style_sheet.dart';
export 'src/widget.dart';
```

### 2. Widget Layer: `lib/src/widget.dart` (590 lines)

**Key classes:**

- `MarkdownWidget` (abstract StatefulWidget, line 202) -- base class providing all configuration
  parameters: `data`, `selectable`, `styleSheet`, `builders`, `extensionSet`, etc.
- `_MarkdownWidgetState` (line 337) -- implements `MarkdownBuilderDelegate`, owns the parse
  lifecycle.
- `MarkdownBody` (line 445) -- non-scrolling variant used in Soliplex chat bubbles.
- `Markdown` (line 499) -- scrolling variant wrapping children in a `ListView`.

**Critical streaming path** (line 348-353):

```dart
@override
void didUpdateWidget(MarkdownWidget oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.data != oldWidget.data || widget.styleSheet != oldWidget.styleSheet) {
    _parseMarkdown();
  }
}
```

Every time `data` changes (every token during streaming), `_parseMarkdown()` (line 361):

1. Creates a new `md.Document` and parses ALL lines.
2. Constructs a new `MarkdownBuilder` and builds ALL widgets.
3. Replaces `_children` entirely.
4. Disposes and recreates all gesture recognizers.

**Extensibility surface:**

- `builders: Map<String, MarkdownElementBuilder>` (line 296) -- custom tag renderers
- `paddingBuilders: Map<String, MarkdownPaddingBuilder>` (line 309) -- custom padding
- `blockSyntaxes` / `inlineSyntaxes` (lines 266-269) -- custom parse rules
- `imageBuilder`, `checkboxBuilder`, `bulletBuilder` -- widget overrides
- `onTapLink` callback (line 254) -- link handling

### 3. Builder Layer: `lib/src/builder.dart` (1034 lines)

The core rendering engine. Implements `md.NodeVisitor` to walk the markdown AST and produce
a widget tree.

**Key pattern -- Visitor traversal:**

```dart
// builder.dart:184-211
List<Widget> build(List<md.Node> nodes) {
  _listIndents.clear();
  _blocks.clear();
  // ...
  _blocks.add(_BlockElement(null));
  for (final md.Node node in nodes) {
    assert(_blocks.length == 1);
    node.accept(this);
  }
  _addAnonymousBlockIfNeeded();
  return _blocks.single.children;
}
```

**Concerning global mutation** (line 192-196):

```dart
builders.forEach((String key, MarkdownElementBuilder value) {
  if (value.isBlockElement()) {
    _kBlockTags.add(key);  // MUTATES MODULE-LEVEL LIST
  }
});
```

The module-level `_kBlockTags` list (line 13) is mutated every `build()` call. If custom
block builders are registered, duplicate entries accumulate across rebuilds. This is a latent
bug that could cause subtle issues during streaming.

**Text widget construction** (line 980-1003):

```dart
Widget _buildRichText(TextSpan text, {TextAlign? textAlign, String? key}) {
  final Key k = key == null ? UniqueKey() : Key(key);
  if (selectable) {
    return SelectableText.rich(text, /* ... */ key: k);
  } else {
    return Text.rich(text, /* ... */ key: k);
  }
}
```

Every text widget gets a `UniqueKey()`, which means Flutter **cannot reuse** any text widget
across rebuilds. This is intentional (prevents gesture recognizer conflicts) but costly for
streaming.

**Inline span merging** (lines 822-868): Adjacent `TextSpan` children are merged into single
spans, and similar text spans are consolidated (lines 941-978). This is efficient for the
final output but happens on every rebuild.

### 4. Style Layer: `lib/src/style_sheet.dart` (857 lines)

`MarkdownStyleSheet` is a large value class with ~50 properties covering every markdown
element type. Factory constructors:

- `fromTheme(ThemeData)` (line 101) -- Material Design defaults
- `fromCupertinoTheme(CupertinoThemeData)` (line 168) -- iOS defaults
- `largeFromTheme(ThemeData)` (line 277) -- larger heading sizes

The `styles` getter (line 724) returns a `Map<String, TextStyle?>` used by the builder to
look up tag styles.

**Relevant for Soliplex migration:** the `MarkdownStyleSheet` constructor and `copyWith` are
identical to `flutter_markdown`. Our existing style configuration will work without changes.

### 5. Platform Layer: `_functions_io.dart` / `_functions_web.dart`

Conditional import at `builder.dart:9`:

```dart
import '_functions_io.dart' if (dart.library.js_interop) '_functions_web.dart';
```

Each provides:

- `kDefaultImageBuilder` -- handles network, data URI, resource, and file images
- `kDefaultImageErrorWidgetBuilder` -- returns `const SizedBox()` on error
- `kFallbackStyle` -- platform-aware style sheet factory

---

## Scoring Table

| # | Axis | Score | Weight | Weighted |
|---|------|-------|--------|----------|
| 1 | Native Widget Embedding | 7 | 0.10 | 0.70 |
| 2 | Interactive Elements | 6 | 0.08 | 0.48 |
| 3 | Extensibility | 8 | 0.12 | 0.96 |
| 4 | AI Streaming | 3 | 0.15 | 0.45 |
| 5 | Architecture & Design | 7 | 0.10 | 0.70 |
| 6 | Code Quality | 7 | 0.08 | 0.56 |
| 7 | API Compatibility | 10 | 0.12 | 1.20 |
| 8 | Performance | 4 | 0.10 | 0.40 |
| 9 | Feature Completeness | 7 | 0.08 | 0.56 |
| 10 | Accessibility | 4 | 0.07 | 0.28 |
| | **Total** | | **1.00** | **6.29** |

---

## Detailed Axis Analysis

### 1. Native Widget Embedding -- 7/10

**Strengths:**

- `builders` map allows arbitrary `Widget` return from `MarkdownElementBuilder.visitElementAfterWithContext()`.
  Proven in tests: `test/custom_syntax_test.dart` shows `ColoredBox`, `Container`, and `WidgetSpan`
  embedding.
- `isBlockElement()` override (widget.dart:97) lets builders declare block-level widgets, getting
  proper spacing and layout.
- `visitText()` (widget.dart:109) allows custom text rendering per tag.

**Weaknesses:**

- No first-class `WidgetSlot` token in markdown syntax. Every embedded widget requires a custom
  `InlineSyntax` or `BlockSyntax` to parse and a custom `MarkdownElementBuilder` to render.
- Inline widget embedding via `WidgetSpan` works (`test/inline_widget_test.dart:41`) but is
  limited to what `WidgetSpan` supports (no arbitrary layout).

**Code references:**

- `widget.dart:93-138` -- `MarkdownElementBuilder` interface
- `builder.dart:219-221` -- builder dispatch in `visitElementBefore`
- `builder.dart:397-403` -- builder dispatch in `visitElementAfter`
- `test/custom_syntax_test.dart:39-58` -- block widget embedding test
- `test/inline_widget_test.dart:17-48` -- inline widget embedding test

### 2. Interactive Elements -- 6/10

**Strengths:**

- `onTapLink(text, href, title)` callback (widget.dart:254) provides full link metadata,
  enabling modal opens, in-app navigation, etc.
- Gesture recognizers are properly created and disposed (widget.dart:412-421).
- Images inside links inherit tap handling (builder.dart:629-634).

**Weaknesses:**

- Only links (`<a>`) have built-in tap handling. Arbitrary tap targets require custom builders.
- No long-press handling, no context menus on elements.
- Custom builders for `<a>` tags are possible (builder.dart:266 skips default handling when
  `builders.containsKey('a')`), but the interaction is limited to what `TapGestureRecognizer`
  provides.

**Code references:**

- `widget.dart:412-421` -- `createLink()` in delegate
- `builder.dart:266-278` -- link handler creation
- `builder.dart:538-541` -- link handler cleanup

### 3. Extensibility -- 8/10

**Strengths:**

- Three-tier extension: syntax parsers, element builders, and padding builders.
- `blockSyntaxes` and `inlineSyntaxes` allow completely new markdown patterns.
- `builders` map allows custom rendering for any tag, including overriding built-in tags
  like `img` (test/custom_syntax_test.dart:193-213).
- `visitElementAfterWithContext()` passes `BuildContext` enabling theme access, provider
  lookups, etc.
- Demonstrated patterns: subscript syntax, wiki links, inline colored text, custom block
  elements (test/custom_syntax_test.dart).

**Weaknesses:**

- No formal plugin registry or lifecycle. All extensions are passed as constructor parameters.
- No middleware/interceptor pattern for pre/post processing.
- The `_kBlockTags` global mutation issue means block-element custom builders have a side
  effect that leaks across instances.

**Code references:**

- `widget.dart:265-274` -- syntax extension parameters
- `widget.dart:296-309` -- builder parameters
- `builder.dart:192-196` -- block tag registration (with mutation bug)

### 4. AI Streaming -- 3/10

**This is the critical weakness for Soliplex.**

**Problem:** Every token update triggers a full rebuild pipeline:

1. `didUpdateWidget` detects `data` change (widget.dart:348-353)
2. `_parseMarkdown()` runs (widget.dart:361-398):
   - `LineSplitter().convert(widget.data)` -- O(n) string split
   - `document.parseLines(lines)` -- O(n) markdown parse
   - `builder.build(astNodes)` -- O(n) widget construction
3. All gesture recognizers are disposed and recreated (widget.dart:400-409)
4. Every text widget gets `UniqueKey()` (builder.dart:982), preventing Flutter's diff
   algorithm from reusing widgets

**Performance characteristics:**

- At 1000 tokens (~4KB text), each update re-parses and rebuilds everything.
- At 20-50 tokens/second (typical LLM streaming rate), this means 20-50 full rebuilds/second.
- `UniqueKey` on every `Text.rich` forces Flutter to create new `RenderParagraph` objects
  every frame.
- No debouncing, no incremental parsing, no dirty-region tracking.

**Mitigations available:**

- Debounce `setState` in the parent widget (update every 100ms instead of every token).
- Use `MarkdownBody` (not `Markdown`) to avoid `ListView` overhead.
- Keep messages short (Soliplex likely already does this per-bubble).

**Code references:**

- `widget.dart:348-353` -- rebuild trigger
- `widget.dart:361-398` -- full parse pipeline
- `builder.dart:982` -- `UniqueKey()` preventing reuse

### 5. Architecture & Design -- 7/10

**Strengths:**

- Clean three-layer separation: Widget (configuration) / Builder (rendering) / StyleSheet (theming).
- Visitor pattern for AST traversal is textbook correct.
- Delegate pattern (`MarkdownBuilderDelegate`) isolates link creation and code formatting.
- Platform abstraction via conditional imports is the standard Flutter approach.

**Weaknesses:**

- `_kBlockTags` is a module-level mutable list that gets modified during `build()` (builder.dart:192-196).
  This is a design smell -- global state in a rendering pipeline.
- `_BlockElement`, `_TableElement`, `_InlineElement` are internal stack structures managed via
  `List` fields on `MarkdownBuilder`. The builder is stateful and not reusable across calls
  (it clears state at the start of `build()`).
- No separation between parsing and rendering concerns -- `MarkdownBuilder` does both AST
  traversal and widget construction.

**Code references:**

- `builder.dart:13-32` -- module-level mutable state
- `builder.dart:40-74` -- internal stack element classes
- `builder.dart:76-94` -- delegate interface

### 6. Code Quality -- 7/10

**Strengths:**

- Good documentation: all public APIs have doc comments.
- Modern Dart: uses `switch` expressions, `dart:js_interop`, `TextScaler` with deprecation
  handling.
- Proper resource cleanup: `ScrollController.dispose()` (builder.dart:1024-1027),
  `GestureRecognizer.dispose()` (widget.dart:400-409).
- Error handling for images: `kDefaultImageErrorWidgetBuilder` returns empty `SizedBox`
  instead of crashing.

**Weaknesses:**

- The `// ignore:` comment at style_sheet.dart:728-729 and 795-796 suppresses
  `avoid_equals_and_hash_code_on_mutable_classes` -- the class has a mutable `_styles` field.
- The `// TODO` at builder.dart:253-257 acknowledges mutating `@immutable` `TableRow.children`.
- `extractTextFromElement` (builder.dart:298-302) has a confusing ternary that returns empty
  string for elements with attributes but no children.
- No explicit error handling around `int.parse(element.attributes['start']!)` at
  builder.dart:234 -- malformed markdown could throw.

**Code references:**

- `style_sheet.dart:728-729` -- suppressed lint
- `builder.dart:253-257` -- acknowledged immutability violation
- `builder.dart:234` -- unsafe parse

### 7. API Compatibility -- 10/10

**This package is a direct fork of `flutter_markdown`.** The API surface is identical:

| Soliplex Current Usage | `flutter_markdown_plus` Equivalent | Status |
|---|---|---|
| `import 'package:flutter_markdown/flutter_markdown.dart'` | `import 'package:flutter_markdown_plus/flutter_markdown_plus.dart'` | Change import |
| `MarkdownBody(data: text, ...)` | `MarkdownBody(data: text, ...)` | Identical |
| `MarkdownStyleSheet(p: ..., code: ..., codeblockDecoration: ...)` | Same constructor, same fields | Identical |
| `CodeBlockBuilder extends MarkdownElementBuilder` | Same base class, same methods | Identical |
| `builders: {'code': CodeBlockBuilder(...)}` | Same pattern | Identical |
| `SelectionArea` wrapping | Same approach (widget.dart:86-89 documents this) | Identical |

**Migration effort:** Change one import path and one pubspec.yaml dependency line.

**Code references (Soliplex side):**

- `lib/features/chat/widgets/chat_message_widget.dart:6` -- import to change
- `lib/features/chat/widgets/chat_message_widget.dart:117-143` -- `MarkdownBody` usage
- `lib/features/chat/widgets/code_block_builder.dart:5` -- import to change
- `lib/features/chat/widgets/code_block_builder.dart:9` -- `MarkdownElementBuilder` usage

### 8. Performance -- 4/10

**Strengths:**

- `MarkdownBody` with `shrinkWrap: true` (widget.dart:467) avoids unnecessary layout.
- Single-child optimization: returns `children.single` when only one child (widget.dart:479).
- Text span merging reduces widget count (builder.dart:822-868, 941-978).
- `_ScrollControllerBuilder` StatefulWidget properly manages per-code-block scroll controllers
  (builder.dart:1006-1033).

**Weaknesses:**

- Full rebuild on every `data` change (see AI Streaming axis).
- `UniqueKey()` on every text widget (builder.dart:982) defeats Flutter's element reuse.
- `Column` layout for all children (widget.dart:482-486) -- not lazy, all widgets are built
  immediately even if off-screen.
- No memoization of parsed AST or built widgets.
- Global `_kBlockTags` list grows unboundedly with repeated builds using custom block builders.

**Code references:**

- `builder.dart:982` -- UniqueKey
- `widget.dart:479-486` -- Column layout
- `builder.dart:192-196` -- unbounded list growth

### 9. Feature Completeness -- 7/10

**Supported:**

- GFM (GitHub Flavored Markdown) by default (widget.dart:370)
- Headers h1-h6 with alignment and padding
- Paragraphs, emphasis, strong, strikethrough
- Ordered and unordered lists with nesting and checkboxes
- Blockquotes with decoration
- Code blocks with horizontal scrolling and syntax highlighting hook
- Tables with header/body styling, cell decoration, alignment, horizontal scrolling
- Images (network, file, data URI, asset)
- Horizontal rules
- Footnotes / superscript (builder.dart:542-567)
- Links with tap callbacks
- Soft line breaks

**Not supported:**

- LaTeX / math rendering (requires separate `flutter_markdown_plus_latex` package per README)
- Inline HTML (explicitly stated as unsupported in README)
- Mermaid diagrams or other rich embeds
- Collapsible sections / details-summary
- Syntax highlighting (requires custom builder, not built in)

### 10. Accessibility -- 4/10

**Strengths:**

- `selectable` mode uses `SelectableText.rich` (builder.dart:984-994) which provides basic
  screen reader support.
- Non-selectable mode uses `Text.rich` (builder.dart:996-1001) which works with
  `SelectionArea` and provides default semantics.
- Soliplex's `CodeBlockBuilder` wraps code in `Semantics(label: ...)` -- this works because
  the builder returns arbitrary widgets.

**Weaknesses:**

- **Images have no semantic labels.** `_buildImage` (builder.dart:599-635) passes `alt` text
  to `imageBuilder` but the default `kDefaultImageBuilder` in `_functions_io.dart:19-68` does
  NOT pass `alt` as `semanticLabel` to `Image.network`/`Image.file`.
- **Headers have no semantic heading traits.** `h1`-`h6` are rendered as styled `Text` widgets
  without `Semantics(header: true)`.
- **Checkboxes are icons without semantics.** `_buildCheckbox` (builder.dart:637-649) uses
  `Icon` with no `Semantics` wrapper.
- **Lists have no list semantics.** No `Semantics(liveRegion: ...)` or ARIA-equivalent
  structure.
- **Tables have no table semantics.** The `Table` widget does not have accessibility
  annotations for header rows vs body rows.

**Code references:**

- `_functions_io.dart:26-31` -- Image.network without semanticLabel
- `builder.dart:637-649` -- checkbox without Semantics
- `builder.dart:689-715` -- table cell without header semantics

---

## Migration Path from Current `flutter_markdown`

### Step 1: Update `pubspec.yaml`

```yaml
# Remove:
flutter_markdown: ^0.7.4+1

# Add:
flutter_markdown_plus: ^1.0.7
```

### Step 2: Update imports (2 files)

```dart
// In lib/features/chat/widgets/chat_message_widget.dart
// Change:
import 'package:flutter_markdown/flutter_markdown.dart';
// To:
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

// In lib/features/chat/widgets/code_block_builder.dart
// Change:
import 'package:flutter_markdown/flutter_markdown.dart';
// To:
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
```

### Step 3: Verify (no code changes needed)

All of the following Soliplex usage patterns are API-identical:

- `MarkdownBody(data: text, styleSheet: MarkdownStyleSheet(...), builders: {...})`
- `CodeBlockBuilder extends MarkdownElementBuilder`
- `visitElementAfter(md.Element element, TextStyle? preferredStyle)`
- `SelectionArea` wrapping (no `selectable: true` needed)

### Step 4: Run tests

```bash
flutter test test/features/chat/widgets/chat_message_widget_test.dart
```

**Estimated migration time: 15 minutes.**

---

## Soliplex-Specific Verdict

### Recommendation: ADOPT (with caveats)

`flutter_markdown_plus` is the correct choice **if the goal is a maintained fork of our
current package**. It is a zero-friction migration with guaranteed API compatibility.

### Caveats

1. **Streaming performance is the same as today.** This package does not improve the
   token-by-token rendering situation. If we are experiencing jank during streaming now,
   switching to this package will not fix it. The full-rebuild-per-token architecture is
   inherent.

2. **The package is a maintenance fork, not a rethink.** Foresight Mobile is keeping the
   lights on (fixing bugs, updating dependencies) but is not innovating on architecture.
   The CHANGELOG shows mostly bug fixes and minor features since the fork.

3. **For streaming optimization, consider:**
   - Debouncing `setState` to 100ms intervals during streaming
   - A fundamentally different markdown renderer (e.g., `markdown_widget` which uses a
     different rendering strategy)
   - Building a custom solution that parses incrementally

4. **Accessibility gaps require custom work.** Our existing `CodeBlockBuilder` already adds
   `Semantics`, which is good. We would need similar wrappers for images and other elements.

### When to choose `flutter_markdown_plus`

- Minimal migration risk is the top priority
- Current streaming performance is acceptable
- We want to stay close to the `flutter_markdown` ecosystem

### When NOT to choose `flutter_markdown_plus`

- Streaming performance must improve significantly
- We need native widget embedding without custom syntax boilerplate
- Accessibility compliance is a hard requirement

---

## Appendix: File Inventory

| File | Lines | Purpose |
|---|---|---|
| `lib/flutter_markdown_plus.dart` | 11 | Barrel exports |
| `lib/src/widget.dart` | 590 | Widget classes, typedefs, State |
| `lib/src/builder.dart` | 1034 | AST-to-Widget visitor |
| `lib/src/style_sheet.dart` | 857 | MarkdownStyleSheet |
| `lib/src/_functions_io.dart` | 120 | IO platform (images, styles) |
| `lib/src/_functions_web.dart` | 125 | Web platform (images, styles) |
| **Total** | **2737** | |
