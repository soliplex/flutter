# Audit Report: `gpt_markdown` v1.1.5 -- Claude

**Auditor:** Claude Opus 4.6
**Date:** 2026-02-10
**Package:** [gpt_markdown](https://pub.dev/packages/gpt_markdown) v1.1.5
**Publisher:** infinitix.tech | **Likes:** 276 | **Points:** 160 | **Downloads:** 57.7k
**License:** BSD-3-Clause
**Source examined:** `~/dev/markdown-audit/gpt_markdown/lib/` (13 Dart files, ~3,228 LOC)

---

## 1. Architecture Overview

### Design Philosophy

`gpt_markdown` uses a **regex-based, recursive splitting parser** instead of a traditional
AST (Abstract Syntax Tree). Markdown text is split via combined regular expressions, with
matched fragments dispatched to component handlers that return `InlineSpan` trees. This
is fundamentally different from `flutter_markdown`, which delegates to the `markdown`
package's AST parser and then visits nodes.

### Architecture Diagram

```text
                          Input String
                              |
                    +---------v----------+
                    |  GptMarkdown       |
                    |  (StatelessWidget) |
                    |  - LaTeX $ -> \( \[|
                    |  - ClipRRect wrap  |
                    +--------+-----------+
                             |
                    +--------v-----------+
                    |  MdWidget          |
                    |  (StatefulWidget)  |
                    |  - Caches spans in |
                    |    initState and   |
                    |    didUpdateWidget |
                    +--------+-----------+
                             |
               +-------------v--------------+
               |  MarkdownComponent.generate |
               |  (static, recursive)        |
               +----+---+---+---+-----------+
                    |   |   |   |
        +-----------+   |   |   +-------------+
        |               |   |                 |
   +----v----+    +-----v---v--+       +------v------+
   | BlockMd |    | InlineMd   |       | TextSpan    |
   | (global)|    | (inline)   |       | (fallback)  |
   +---------+    +------------+       +-------------+
        |               |
   WidgetSpan      TextSpan / WidgetSpan
   (wrapped in         |
    Row+Flexible)      |
        |               |
        +------+--------+
               |
     +---------v-----------+
     |  Text.rich(TextSpan) |
     |  via config.getRich  |
     +----------------------+
```

### Parsing Pipeline

1. **Pre-processing** (`gpt_markdown.dart:165-181`): Dollar-sign LaTeX converted to
   backslash notation via regex replacement.
2. **Component Registration** (`markdown_component.dart:5-18,20-32`): Two lists --
   `globalComponents` (block-level) and `inlineComponents` (inline-level).
3. **Combined Regex** (`markdown_component.dart:47-51`): All component patterns joined
   with `|` into a single mega-regex.
4. **splitMapJoin** (`markdown_component.dart:52-84`): Text is split by the combined
   regex. Matches are dispatched to their component's `span()` method. Non-matches are
   recursed (global->inline) or emitted as plain `TextSpan`.
5. **Output**: A `List<InlineSpan>` rendered via `Text.rich`.

### Key Dependency

- `flutter_math_fork ^0.7.3` for LaTeX rendering (inline and display math).

---

## 2. Source Walkthrough

### 2.1 `lib/gpt_markdown.dart` (214 lines)

**Purpose:** Entry-point widget and public API surface.

**Key observations:**

- **Constructor parameters (lines 23-47):** Exposes 20 optional parameters including
  builders for code, latex, links, images, tables, ordered/unordered lists, highlights,
  and source tags. Also accepts `components` and `inlineComponents` lists for full
  component replacement.

- **Dollar-sign LaTeX conversion (lines 165-181):**

  ```dart
  tex = tex.replaceAllMapped(
    RegExp(r"(?<!\\)\$\$(.*?)(?<!\\)\$\$", dotAll: true),
    (match) => "\\[${match[1] ?? ""}\\]",
  );
  ```

  This is a destructive pre-processing step. It converts `$$..$$` to `\[..\]` and
  `$..$` to `\(..\)`, but only when `useDollarSignsForLatex` is true. The guard
  `if (!tex.contains(r"\("))` on line 170 means if the text already has `\(`, single
  dollar signs are left alone -- a reasonable but undocumented heuristic.

- **ClipRRect wrapper (line 184):** The entire output is wrapped in `ClipRRect` with no
  border radius specified, which adds a clip layer to the render tree for no visible
  effect.

- **Commented-out code (lines 152-160):** Dead method `_removeExtraLinesInsideBlockLatex`
  left in source.

### 2.2 `lib/markdown_component.dart` (1,244 lines)

**Purpose:** Core parsing engine and all markdown component definitions.

This is the heart of the package, containing the abstract `MarkdownComponent` class and
all concrete implementations: `CodeBlockMd`, `HTag`, `NewLines`, `BlockQuote`, `TableMd`,
`UnOrderedList`, `OrderedList`, `HighlightedText`, `BoldMd`, `StrikeMd`, `ItalicMd`,
`LatexMathMultiLine`, `LatexMath`, `SourceTag`, `ATagMd`, `ImageMd`, `HrLine`,
`CheckBoxMd`, `RadioButtonMd`, `IndentMd`, `UnderLineMd`.

**Critical findings:**

- **Combined regex (lines 46-51):**

  ```dart
  Iterable<String> regexes = components.map<String>((e) => e.exp.pattern);
  final combinedRegex = RegExp(
    regexes.join("|"),
    multiLine: true,
    dotAll: true,
  );
  ```

  The combined regex is reconstructed on every call to `generate()`. With ~12-20
  components, this creates a regex with thousands of characters. The `multiLine` and
  `dotAll` flags are applied globally, even though individual component regexes may have
  different flag requirements.

- **Double-regex matching (lines 56-65):** After `splitMapJoin` finds a match with the
  combined regex, the code iterates all components and re-tests with `^pattern$` to find
  which specific component matched. This is O(N) per match where N = component count.

- **Recursive dispatch (lines 74-76):** Non-matching text in global pass is recursed
  with `includeGlobalComponents: false` to try inline components:

  ```dart
  var newSpans = generate(context, p0, config.copyWith(), false);
  ```

  Note `config.copyWith()` is called with no arguments, creating a needless copy.

- **BlockMd base class (lines 111-155):** All block components get wrapped in
  `Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: ...)])` and then a
  `WidgetSpan` with `PlaceholderAlignment.baseline`. This wrapping pattern means every
  block element produces a Row with a single Flexible child -- adding unnecessary layout
  nodes.

- **HTag heading detection (lines 193-241):** Heading styles use array indexing
  `[match![1]!.length - 1]` with force-unwrap. If the regex somehow fails to capture
  group 1, this will throw a null check error at runtime.

- **TableMd memory leak (lines 1094):**

  ```dart
  final controller = ScrollController();
  return Scrollbar(
    controller: controller,
    child: SingleChildScrollView(
      controller: controller,
  ```

  A `ScrollController` is created inside the `build()` method of a component that
  returns a `WidgetSpan`. This controller is never disposed. In a chat application with
  many messages containing tables, this will leak native resources.

- **ATagMd balanced parenthesis scanner (lines 793-846):** Manually counts `[` and `(`
  brackets to handle nested URLs like
  `[text](https://en.wikipedia.org/wiki/Markdown_(software))`. This is correct but
  fragile -- a mismatch in brackets will return `TextSpan()` silently.

- **LatexMath and LatexMathMultiLine (lines 585-733):** Both contain ~50 lines of nearly
  identical code for the default LaTeX builder. This should be extracted into a shared
  helper.

- **Inline code highlighting (lines 453-496):** Uses `Paint()..color` as a background
  paint on `TextStyle`. This is a non-standard approach that may not interact well with
  all Flutter text renderers (e.g., Impeller).

### 2.3 `lib/md_widget.dart` (84 lines)

**Purpose:** Stateful widget that caches parsed InlineSpan trees.

**Critical findings:**

- **BuildContext stored as widget field (lines 4-11):**

  ```dart
  class MdWidget extends StatefulWidget {
    const MdWidget(
      this.context,
      this.exp,
      this.includeGlobalComponents, {
      ...
    });
    final BuildContext context;
  ```

  Storing `BuildContext` in a widget is a well-known anti-pattern. BuildContext is valid
  only during the build phase and can become stale if the widget is moved in the tree or
  the parent is disposed. In `initState` (line 32), the stored parent context is used
  for `MarkdownComponent.generate`, but `initState` does not have access to this
  widget's own context yet in a safe way for layout queries.

- **didUpdateWidget comparison (lines 41-51):** Uses `config.isSame()` which only
  compares a subset of fields (see markdown_config.dart analysis below).

- **CustomTableColumnWidth (lines 69-84):** Calls `each.layout(const BoxConstraints(),
  parentUsesSize: true)` inside `maxIntrinsicWidth`. Performing unconstrained layout
  during intrinsic measurement is technically correct but may cause issues with complex
  table cell contents.

### 2.4 `lib/theme.dart` (208 lines)

**Purpose:** Theme data and InheritedWidget for styling.

- **GptMarkdownThemeData** extends `ThemeExtension`, allowing it to be registered via
  `Theme.of(context).extension<GptMarkdownThemeData>()`. This is a good pattern.
- **Theme resolution (lines 190-201):** Falls back through InheritedWidget lookup,
  ThemeExtension lookup, then auto-generation from the current ThemeData. Well-designed
  fallback chain.
- **Mutable fields (lines 93-119):** The ThemeData class has non-final fields
  (`Color highlightColor`, `TextStyle? h1`, etc.). For a theme data class, these should
  be `final` for immutability guarantees.
- **lerp implementation (lines 155-177):** Proper implementation supporting animated
  theme transitions.

### 2.5 `lib/custom_widgets/markdown_config.dart` (239 lines)

**Purpose:** Configuration object passed through the rendering pipeline.

- **isSame() partial comparison (lines 218-237):**

  ```dart
  bool isSame(GptMarkdownConfig other) {
    return style == other.style &&
        textAlign == other.textAlign &&
        // latexWorkaround == other.latexWorkaround &&
        // components == other.components &&
        // ...11 more commented-out comparisons...
        textDirection == other.textDirection;
  }
  ```

  This means changing builders, components, or callbacks at runtime will NOT trigger
  `MdWidget` to re-parse. This is a latent bug for any app that dynamically changes
  configuration.

- **getRich helper (lines 206-215):** Creates `Text.rich` with standard parameters.
  Clean utility method.

### 2.6 `lib/custom_widgets/code_field.dart` (87 lines)

**Purpose:** Default code block rendering with copy button.

- Uses `JetBrainsMono` font bundled with the package (good default).
- Copy-to-clipboard with visual feedback (checkmark icon for 2 seconds).
- **No syntax highlighting** -- just monospace text display. The `codeBuilder` callback
  must be used for highlighting.
- The `Future.delayed` in `onPressed` (line 58) can cause `setState` after disposal
  if the widget is removed during the delay. Missing `mounted` check.

### 2.7 `lib/custom_widgets/selectable_adapter.dart` (363 lines)

**Purpose:** Custom selection support for non-text widgets (LaTeX).

- Implements `Selectable` and `SelectionRegistrant` mixins on a custom RenderProxyBox.
- Handles all `SelectionEventType` cases including granular and directional extension.
- Returns `SelectedContent(plainText: selectedText)` for copy operations.
- **This is well-implemented** and addresses a real gap in Flutter's selection system
  for non-text content.

### 2.8 `lib/custom_widgets/custom_divider.dart` (104 lines)

**Purpose:** Custom RenderObject divider for horizontal rules.

- **Bug (line 100):** `Rect.largest.size.width` is used as the divider width:

  ```dart
  context.canvas.drawRect(
    offset & Size(Rect.largest.size.width, _height),
    Paint()..color = _color,
  );
  ```

  `Rect.largest` has a width of `double.maxFinite`. Painting a rect of essentially
  infinite width is wasteful and could cause issues with canvas bounds. Should use
  `size.width` from the layout phase instead.

### 2.9 `lib/custom_widgets/custom_error_image.dart` (306 lines)

**Purpose:** Custom render objects for image loading/error states.

- Two custom `RenderProxyBox` subclasses for error and loading states.
- Draws Material Icons via `TextPainter` with icon font -- clever approach.
- `updateRenderObject` directly sets private fields (e.g., `renderObject._backgroundColor`)
  instead of using the public setters. This bypasses the `markNeedsPaint()` guards.

### 2.10 `lib/custom_widgets/custom_rb_cb.dart` (102 lines)

**Purpose:** Checkbox and radio button widgets for task list rendering.

- Uses Material `Checkbox` and `RadioGroup` / `Radio` widgets.
- `onChanged: (value) {}` -- checkboxes and radios are non-interactive (display only).

### 2.11 `lib/custom_widgets/indent_widget.dart` (68 lines)

**Purpose:** Block quote rendering with CustomPainter.

- `shouldRepaint` always returns `true` (line 65) -- will repaint on every frame that
  triggers a paint, even when nothing changes.

### 2.12 `lib/custom_widgets/link_button.dart` (88 lines)

**Purpose:** Link rendering with hover state.

- `_handlePress` calls `setState(() {})` with empty body (line 86) -- triggers rebuild
  for no state change.

### 2.13 `lib/custom_widgets/unordered_ordered_list.dart` (121 lines)

**Purpose:** List item rendering with bullet/number decorations.

- Clean, simple widgets. Uses `CrossAxisAlignment.baseline` for alignment.

---

## 3. Scoring Table

| # | Requirement | Score | Justification |
|---|-------------|:-----:|---------------|
| 1 | **Native Widget Embedding** | 5/10 | Block components produce `WidgetSpan` wrappers, so arbitrary widgets CAN be embedded via custom components or builders (e.g., `codeBuilder`, `tableBuilder`). However, there is no first-class API for inserting arbitrary widgets at arbitrary positions -- you must write a regex pattern and component class. |
| 2 | **Interactive Elements** | 6/10 | `onLinkTap(url, title)` callback provides custom link handling (modals, not just URL launch). `linkBuilder` allows custom link widgets. Code blocks have copy buttons. Checkboxes/radios are display-only. |
| 3 | **Extensibility** | 5/10 | Custom `components` and `inlineComponents` lists allow full replacement. Multiple builder typedefs (`CodeBlockBuilder`, `LatexBuilder`, `TableBuilder`, `LinkBuilder`, `ImageBuilder`, etc.) allow targeted customization. However, adding a new component requires writing regex patterns -- error-prone and hard to debug. No plugin discovery or registration API. |
| 4 | **AI Streaming** | 3/10 | `MdWidget` is `StatefulWidget` and caches spans in `didUpdateWidget`, avoiding rebuild when data unchanged. BUT: every text change triggers full re-parse of entire string via `MarkdownComponent.generate()`. No incremental/delta parsing. No debouncing. For a 2000-word streaming message at 50 tokens/sec, this means 50 full regex re-parses per second. Code blocks that are unclosed during streaming are handled (`closed` parameter). |
| 5 | **Architecture & Design** | 3/10 | Regex-based parsing is fragile for a context-sensitive grammar like Markdown. `part of` file structure prevents independent testing. BuildContext stored as widget field. Dual-pass (global then inline) is reasonable in concept but implementation leaks concerns. |
| 6 | **Code Quality** | 4/10 | Commented-out code throughout. Memory leak in TableMd. Mutable fields in theme data. `Rect.largest` in paint. Empty `setState`. Always-true `shouldRepaint`. Missing `mounted` checks on async operations. Force-unwraps without guards. However: reasonable doc comments, consistent naming, clear class hierarchy. |
| 7 | **API Compatibility** | 3/10 | Completely different API from `flutter_markdown`. No `MarkdownBody`, no `MarkdownStyleSheet`, no `MarkdownElementBuilder`. Migration requires rewriting all integration code. Theming concept exists but with different shape. Builder signatures differ entirely. |
| 8 | **Performance** | 4/10 | Caches spans to avoid rebuild on identical data (good). But: full re-parse on every change (bad for streaming). Combined regex rebuilt every generate() call. ScrollController leak. Unnecessary ClipRRect. Unnecessary Row+Flexible wrappers on every block element. `shouldRepaint: true` in block quote painter. |
| 9 | **Feature Completeness** | 8/10 | Covers: headings (h1-h6), bold, italic, strikethrough, underline, code blocks, inline code, blockquotes, ordered/unordered lists, tables with alignment, images with size parsing, links with nested parens, LaTeX inline and display, checkboxes, radio buttons, horizontal rules, source tags, indentation. Missing: footnotes, definition lists, task list interactivity, HTML passthrough. |
| 10 | **Accessibility** | 2/10 | No `Semantics` widgets anywhere. Custom render objects (`RenderDivider`, `RenderCustomImageError`) have no semantic annotations. Images have alt text in the regex but it is used for sizing, not semantics. LaTeX is selectable via `SelectableAdapter` (good) but has no semantic label. Screen readers will struggle with most content. |

**Weighted Average: 4.3/10**

---

## 4. Specific Concerns

### 4.1 Regex-Based Parsing vs AST

**Risk level: HIGH**

The `markdown` package (used by `flutter_markdown`) implements a proper parser based on
the CommonMark specification. It builds an AST, handles precedence, and resolves
ambiguities according to the spec.

`gpt_markdown` uses `splitMapJoin` with a combined regex. This approach:

- Cannot handle nested structures correctly (e.g., bold inside italic inside a link).
  The first-matching-component-wins strategy means component ordering matters.
- Is vulnerable to catastrophic backtracking on adversarial input. For example, the
  code block regex `r"```(.*?)\n((.*?)(:?\n\s*?```)|(.*)(:?\n```)?)$"` with `dotAll`
  can backtrack exponentially on certain inputs.
- Cannot produce correct output for edge cases that are well-defined in CommonMark
  but require context (e.g., list continuation, lazy continuation lines, reference
  links).

For an AI chat app, LLM output is unpredictable. Regex failures will manifest as raw
markdown symbols appearing in the chat UI or, worse, as UI freezes from backtracking.

### 4.2 `part of` File Structure

All core files (`markdown_component.dart`, `md_widget.dart`, `theme.dart`) are `part of
'gpt_markdown.dart'`. This means:

- They share a single library namespace -- no encapsulation between files.
- They cannot be independently imported or tested.
- IDE navigation and refactoring tools work less well.
- Circular references are easy to introduce.

This is considered an anti-pattern in modern Dart. The `part` directive exists primarily
for code generation (e.g., `json_serializable`), not manual code organization.

### 4.3 MdWidget Storing BuildContext

`md_widget.dart:8`: `final BuildContext context;`

This violates Flutter's contract that BuildContext is ephemeral and scoped to the build
phase. Consequences:

- If the parent widget that provided this context is disposed, the stored context becomes
  stale. Calling `Theme.of(storedContext)` will throw.
- In `initState()` (line 32), the stored parent context is used to generate spans. If
  the widget is reparented (e.g., via GlobalKey), the context will be wrong.
- The context is used in `MarkdownComponent.generate()` to look up theme data and
  build widgets, meaning theme changes in the subtree may not be reflected.

### 4.4 isSame() Partial Comparison

`markdown_config.dart:218-237`: Only `style`, `textAlign`, `textScaler`, `maxLines`,
`overflow`, `followLinkColor`, and `textDirection` are compared. Eleven function/list
fields are commented out.

Impact: If Soliplex changes a builder callback (e.g., switches code highlighter theme),
`MdWidget` will NOT re-parse. The stale cached spans will persist until the text itself
changes.

### 4.5 ScrollController Leak in TableMd

`markdown_component.dart:1094`: Created in `build()`, never disposed.

In a chat app displaying 50+ messages, each containing a table, this creates 50+ leaked
controllers. Each controller registers listeners with the scroll position. Over time,
this will degrade performance and increase memory usage.

### 4.6 Custom RenderObject Usage

The package uses custom RenderObjects for:

- `CustomDivider` / `RenderDivider` (horizontal rule)
- `CustomImageError` / `RenderCustomImageError` (error placeholder)
- `CustomImageLoading` / `RenderCustomImageLoading` (loading placeholder)
- `SelectableAdapter` / `_RenderSelectableAdapter` (selection)

The first three are simple enough that they could be standard widgets (`Container`,
`LinearProgressIndicator`). Using custom RenderObjects adds maintenance burden and
potential for subtle bugs (like the `Rect.largest` issue in `RenderDivider`).

The `SelectableAdapter` is the exception -- it solves a genuine problem (making non-text
content selectable) and is well-implemented.

---

## 5. Migration Path from flutter_markdown

### Effort Estimate: MEDIUM-HIGH (3-5 days)

### Step-by-step

1. **Dependency swap**

   ```yaml
   # Remove
   flutter_markdown: ^0.7.4+1
   # Add
   gpt_markdown: ^1.1.5
   ```

2. **Widget replacement**

   ```dart
   // Before
   MarkdownBody(
     data: message.content,
     styleSheet: soliplexStyleSheet,
     builders: {'code': CodeBlockBuilder()},
     onTapLink: (text, href, title) => handleLink(href),
   )

   // After
   GptMarkdown(
     message.content,
     style: theme.textTheme.bodyMedium,
     codeBuilder: (context, name, code, closed) => SoliplexCodeBlock(...),
     onLinkTap: (url, title) => handleLink(url),
   )
   ```

3. **Theming migration**

   ```dart
   // Before: MarkdownStyleSheet
   MarkdownStyleSheet(
     h1: theme.textTheme.headlineLarge,
     code: TextStyle(fontFamily: 'JetBrainsMono'),
     blockquoteDecoration: BoxDecoration(...),
   )

   // After: GptMarkdownThemeData via ThemeExtension
   Theme(
     data: theme.copyWith(
       extensions: [
         GptMarkdownThemeData(
           brightness: theme.brightness,
           h1: theme.textTheme.headlineLarge,
           linkColor: theme.colorScheme.primary,
         ),
       ],
     ),
     child: ...,
   )
   ```

4. **Selection handling**
   Remove any `SelectionArea` wrapper around the markdown widget.
   `gpt_markdown` handles selection internally via `SelectableAdapter`.
   Wrapping in `SelectionArea` may cause double selection handles.

5. **Code block builder migration**

   ```dart
   // Before: extends MarkdownElementBuilder
   class CodeBlockBuilder extends MarkdownElementBuilder {
     @override
     Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
       final code = element.textContent;
       final language = element.attributes['class']?.replaceAll('language-', '');
       return SoliplexCodeBlock(language: language, code: code);
     }
   }

   // After: CodeBlockBuilder typedef
   codeBuilder: (BuildContext context, String name, String code, bool closed) {
     return SoliplexCodeBlock(language: name, code: code, closed: closed);
   }
   ```

6. **Streaming considerations**
   If Soliplex currently throttles or debounces markdown updates, that logic becomes
   MORE important with `gpt_markdown` due to the full re-parse on every update. Consider
   adding a frame-rate limiter (e.g., update at most every 100ms).

### Breaking changes to address

- `MarkdownStyleSheet` properties that have no `GptMarkdownThemeData` equivalent (e.g.,
  `blockquoteDecoration`, `tableBorder`, `listBullet`).
- `extensionSet: ExtensionSet.gitHubWeb` has no equivalent -- GFM support is baked in
  but with regex-level fidelity.
- `imageBuilder` signature changes from `(Uri, String?, String?)` to
  `(BuildContext, String)`.

---

## 6. Verdict

### HOLD

**Do not adopt `gpt_markdown` for Soliplex production at this time.**

#### Reasons to hold (not reject outright)

**Strengths:**

- LaTeX support out of the box (major feature for AI chat).
- Builder-based customization for all major elements.
- Selection support for non-text content via `SelectableAdapter`.
- Active development (v1.1.5, recent commits, Flutter 3.35+ requirement).
- BSD-3-Clause license is compatible.
- Feature set covers 90% of AI chat rendering needs.

**Blockers for production:**

1. **Memory leak in TableMd** -- must be fixed before production use.
2. **BuildContext stored as widget field** -- can cause crashes in list-recycled chat.
3. **Full re-parse on every streaming token** -- will cause jank on mobile for long
   messages without external throttling.
4. **No accessibility semantics** -- fails WCAG compliance.
5. **Regex parsing correctness** -- edge cases with nested markdown will produce
   incorrect rendering for unpredictable LLM output.
6. **isSame() partial comparison** -- dynamic theme changes silently ignored.

#### Recommended path forward

1. **Short term:** Stay on `flutter_markdown` with custom builders. Add LaTeX support
   via a custom `MarkdownElementBuilder` wrapping `flutter_math_fork`.
2. **Monitor:** Watch `gpt_markdown` for fixes to the issues identified above,
   particularly the memory leak and BuildContext storage.
3. **Prototype:** Build a branch with `gpt_markdown` to test real-world streaming
   performance with Soliplex's actual message volume before making a decision.
4. **Contribute:** Consider filing issues or PRs for the memory leak, accessibility,
   and isSame() bugs upstream.

---

## Appendix: File Reference

| File | Lines | Purpose |
|------|------:|---------|
| `lib/gpt_markdown.dart` | 214 | Entry point, GptMarkdown widget |
| `lib/markdown_component.dart` | 1,244 | Parser engine, all components |
| `lib/md_widget.dart` | 84 | Stateful span cache widget |
| `lib/theme.dart` | 208 | GptMarkdownThemeData, InheritedWidget |
| `lib/custom_widgets/markdown_config.dart` | 239 | Configuration object, builder typedefs |
| `lib/custom_widgets/code_field.dart` | 87 | Default code block widget |
| `lib/custom_widgets/custom_divider.dart` | 104 | Custom RenderObject divider |
| `lib/custom_widgets/custom_error_image.dart` | 306 | Image error/loading RenderObjects |
| `lib/custom_widgets/custom_rb_cb.dart` | 102 | Checkbox/radio display widgets |
| `lib/custom_widgets/selectable_adapter.dart` | 363 | Selection support for non-text |
| `lib/custom_widgets/unordered_ordered_list.dart` | 121 | List item widgets |
| `lib/custom_widgets/indent_widget.dart` | 68 | Block quote painter |
| `lib/custom_widgets/link_button.dart` | 88 | Link with hover state |
