# ADR: Markdown Renderer Abstraction

## Status

Proposed

## Context

AI chat responses are rendered as markdown via `flutter_markdown`, tightly
coupled in two files. The rendering lacks critical features (link handling,
image interaction, code copy, HTML filtering, theming) and the package cannot
be swapped without modifying consumer code.

See [SPEC.md](./SPEC.md) for requirements and use cases.

**Issue:** <https://github.com/soliplex/flutter/issues/100>

### Current Architecture

```dart
// chat_message_widget.dart lines 117-143
MarkdownBody(
  data: text,
  styleSheet: MarkdownStyleSheet(
    p: theme.textTheme.bodyLarge?.copyWith(...),
    code: context.monospace.copyWith(...),
    codeblockDecoration: BoxDecoration(...),
  ),
  builders: {
    'code': CodeBlockBuilder(preferredStyle: context.monospace.copyWith(...)),
  },
)
```

Direct `MarkdownBody` usage with inline style configuration. No abstraction
layer. `CodeBlockBuilder` extends `MarkdownElementBuilder` (package type)
directly.

**Import surface:**

- `chat_message_widget.dart` — imports `flutter_markdown`
- `code_block_builder.dart` — imports `flutter_markdown` and `markdown`

## Decision

### Approach: Adapter Pattern at the Widget Boundary

Markdown rendering is a presentation concern — string in, widget tree out.
This is not a data source (Gateway) or business logic (Interactor). The correct
abstraction is an **Adapter** that translates our app's rendering contract into
whatever package we use today.

#### How the Adapter Works

```text
Consumer (ChatMessageWidget)
    │
    │  depends on
    ▼
MarkdownRenderer (abstract)        ← the contract
    │  - data: String
    │  - onLinkTap callback
    │  - onImageTap callback
    │  - blockExtensions map
    │
    │  implemented by
    ▼
FlutterMarkdownPlusRenderer        ← the adapter
    │
    │  translates to
    ▼
MarkdownBody (flutter_markdown_plus)  ← the package
    ├── CodeBlockBuilder (package-specific)
    ├── MarkdownStyleSheet (package-specific)
    └── onTapLink, imageBuilder (package-specific callbacks)
```

The adapter is a thin `build()` method that maps our API to the package's API.
No logic, no state, just translation. For example, our generic
`onLinkTap(href, title)` is wired to the package's specific
`onTapLink(text, href, title)`.

**Containment boundary:** Everything inside `shared/widgets/markdown/` may
import the markdown package. Nothing outside that directory ever does. The
concrete renderer and its supporting files (e.g., `CodeBlockBuilder`) are a
unit — when swapping packages, you rewrite them together.

**To swap packages:** Write a new concrete renderer (e.g.,
`SmoothMarkdownRenderer extends MarkdownRenderer`) that translates the same
contract into the new package's API. Update one import in consumers. Done.

### Key Design Decisions

#### 1. Abstract Widget as Contract

Define `MarkdownRenderer` as an abstract `StatelessWidget`:

```dart
abstract class MarkdownRenderer extends StatelessWidget {
  const MarkdownRenderer({
    super.key,
    required this.data,
    this.onLinkTap,
    this.onImageTap,
    this.blockExtensions = const {},
  });

  final String data;
  final void Function(String href, String? title)? onLinkTap;
  final void Function(String src, String? alt)? onImageTap;
  final Map<String, MarkdownBlockExtension> blockExtensions;
}
```

**Rationale:** In Flutter, widgets ARE the abstraction boundary. An abstract
widget documents the contract explicitly. Consumers depend on
`MarkdownRenderer`, never on the concrete class or the package. When swapping
packages, write a new concrete class — no consumer changes.

#### 2. ThemeExtension for Style Mapping

Create `MarkdownThemeExtension` extending `ThemeExtension<T>`:

```dart
class MarkdownThemeExtension extends ThemeExtension<MarkdownThemeExtension> {
  final TextStyle? h1;
  final TextStyle? h2;
  final TextStyle? h3;
  final TextStyle? body;
  final TextStyle? code;
  final TextStyle? link;
  final BoxDecoration? codeBlockDecoration;
  final BoxDecoration? blockquoteDecoration;

  /// Adapter method: converts app theme to the package's format.
  /// Only code that knows both our theme AND the package's types.
  MarkdownStyleSheet toMarkdownStyleSheet() { ... }
}
```

**Rationale:** The app shell owns the design system. The markdown renderer
receives theme through Flutter's standard `Theme.of(context)` mechanism. The
`toMarkdownStyleSheet()` method is the only package-coupled code in the theme
layer. When swapping packages, rewrite this one method.

#### 3. HTML Sanitization Inside the Adapter

The concrete renderer sanitizes markdown input before passing to the package:

```dart
String _sanitize(String raw) {
  return raw.replaceAll(RegExp(r'<br\s*/?>'), '\n');
}
```

**Rationale:** HTML filtering is an implementation detail. Different packages
handle stray HTML differently. Sanitization belongs in the concrete adapter,
not in the abstract contract or the consumer.

#### 4. Callbacks Over Widget Parameters

Link and image taps are exposed as callbacks (`onLinkTap`, `onImageTap`)
rather than configuration objects.

**Rationale:** Callbacks are the simplest abstraction. The consumer decides
what to do (open browser, show fullscreen viewer). The adapter translates
callbacks to the package's specific API (`onTapLink`, `imageBuilder`). This
keeps the adapter thin and the consumer in control.

#### 5. Custom Block Extensions as Package-Agnostic Types

Custom blocks are registered via `MarkdownBlockExtension`:

```dart
class MarkdownBlockExtension {
  const MarkdownBlockExtension({
    required this.pattern,
    required this.tag,
    required this.builder,
  });

  final RegExp pattern;
  final String tag;
  final Widget Function(String content, Map<String, String> attributes) builder;
}
```

The concrete adapter translates each extension into the package's
`BlockSyntax` subclass + `MarkdownElementBuilder`.

**Rationale:** Custom blocks need syntax detection (pattern) and widget
rendering (builder). Exposing these as simple Dart types rather than
package-specific classes means custom block consumers (map widget, chart
widget) never import the markdown package. When swapping packages, only the
adapter's translation logic changes.

#### 6. FullscreenImageViewer as Standalone Widget

The fullscreen image viewer is a separate reusable widget, not embedded in the
adapter.

**Rationale:** Fullscreen image viewing is useful beyond markdown (e.g.,
attached images, avatars). The adapter's `onImageTap` callback triggers
navigation to the viewer. The viewer itself knows nothing about markdown.

### Components

#### MarkdownRenderer (Abstract)

```dart
typedef MarkdownLinkHandler = void Function(String href, String? title);
typedef MarkdownImageHandler = void Function(String src, String? alt);

abstract class MarkdownRenderer extends StatelessWidget {
  const MarkdownRenderer({
    super.key,
    required this.data,
    this.onLinkTap,
    this.onImageTap,
    this.blockExtensions = const {},
  });

  final String data;
  final MarkdownLinkHandler? onLinkTap;
  final MarkdownImageHandler? onImageTap;
  final Map<String, MarkdownBlockExtension> blockExtensions;
}
```

#### FlutterMarkdownPlusRenderer (Concrete)

```dart
class FlutterMarkdownPlusRenderer extends MarkdownRenderer {
  const FlutterMarkdownPlusRenderer({
    super.key,
    required super.data,
    super.onLinkTap,
    super.onImageTap,
    super.blockExtensions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<MarkdownThemeExtension>();

    return MarkdownBody(
      data: _sanitize(data),
      styleSheet: theme?.toMarkdownStyleSheet(),
      onTapLink: (text, href, title) {
        if (href != null) onLinkTap?.call(href, title);
      },
      imageBuilder: _buildImage,
      builders: _buildBuilders(context),
      blockSyntaxes: _buildBlockSyntaxes(),
    );
  }
}
```

#### MarkdownThemeExtension

```dart
class MarkdownThemeExtension extends ThemeExtension<MarkdownThemeExtension> {
  const MarkdownThemeExtension({
    this.h1, this.h2, this.h3,
    this.body, this.code, this.link,
    this.codeBlockDecoration,
    this.blockquoteDecoration,
  });

  final TextStyle? h1;
  final TextStyle? h2;
  final TextStyle? h3;
  final TextStyle? body;
  final TextStyle? code;
  final TextStyle? link;
  final BoxDecoration? codeBlockDecoration;
  final BoxDecoration? blockquoteDecoration;

  MarkdownStyleSheet toMarkdownStyleSheet() {
    return MarkdownStyleSheet(
      h1: h1, h2: h2, h3: h3,
      p: body, code: code, a: link,
      codeblockDecoration: codeBlockDecoration,
      blockquoteDecoration: blockquoteDecoration,
    );
  }

  @override
  MarkdownThemeExtension copyWith({...}) { ... }

  @override
  MarkdownThemeExtension lerp(MarkdownThemeExtension? other, double t) { ... }
}
```

#### MarkdownBlockExtension

```dart
class MarkdownBlockExtension {
  const MarkdownBlockExtension({
    required this.pattern,
    required this.tag,
    required this.builder,
  });

  final RegExp pattern;
  final String tag;
  final Widget Function(String content, Map<String, String> attributes) builder;
}
```

### File Layout

```text
lib/shared/widgets/markdown/
  markdown_renderer.dart            # Abstract widget + typedefs
  markdown_theme_extension.dart     # ThemeExtension
  markdown_block_extension.dart     # Custom block type
  flutter_markdown_plus_renderer.dart  # Concrete adapter
  code_block_builder.dart           # Code fence builder (moved from features/chat)

lib/shared/widgets/
  fullscreen_image_viewer.dart      # Standalone fullscreen image widget
```

## Consequences

### Positive

- Package swap is a 3-file change (concrete renderer, theme adapter method,
  pubspec).
- Theme integration follows Flutter's standard ThemeExtension pattern.
- Consumers never import the markdown package.
- Custom block extensions are package-agnostic.
- Incremental delivery — each slice delivers user value.
- FullscreenImageViewer is reusable beyond markdown.

### Negative

- Abstract widget adds a level of indirection (minimal — it's one class).
- `toMarkdownStyleSheet()` is package-specific code in the theme extension.
- Custom block translation in the adapter adds complexity.

### Risks

- **flutter_markdown_plus discontinuation:** The package is already a
  continuation of the discontinued `flutter_markdown`. If it's discontinued
  again, the adapter makes migration straightforward.
- **Custom block abstraction mismatch:** If a future package has a radically
  different extension model, the `MarkdownBlockExtension` abstraction may need
  redesigning. Acceptable risk — we'll cross that bridge when we get there.

## Alternatives Considered

### 1. Gateway + Interactor Pattern

**Approach:** Wrap the markdown package in a Gateway, consume through
Interactors.

**Rejected because:**

- Markdown rendering is a presentation concern, not a data/business concern.
- Gateways abstract data sources; Interactors orchestrate business logic.
  Neither applies here.
- Would violate the Dependency Rule by pulling a UI concern toward the domain.
- Adds layers without adding value.

### 2. No Abstraction (Direct Package Usage)

**Approach:** Replace `flutter_markdown` with `flutter_markdown_plus` directly
in consumer code.

**Rejected because:**

- Only 2 import sites today, but more consumers may appear (settings preview,
  help screens, etc.).
- Swapping packages requires understanding each consumer's usage.
- Package types leak into consumer code.

### 3. Provider-Based Factory

**Approach:** Expose a `markdownRendererProvider` that returns a factory
function.

**Rejected because:**

- Adds Riverpod machinery for no benefit — we don't need runtime polymorphism.
- A simple abstract widget class achieves the same goal with less ceremony.
- YAGNI — if we ever need runtime package switching, we can add a provider
  then.

### 4. flutter_smooth_markdown

**Approach:** Use `flutter_smooth_markdown` instead of `flutter_markdown_plus`.

**Considered but deferred:**

- A prototype exists (see diff in `/Users/jaeminjo/Downloads/diff`) showing
  migration from `flutter_markdown_plus` to `flutter_smooth_markdown` with
  custom widget extensions (map, pie chart).
- `flutter_smooth_markdown` has a cleaner plugin API (`BlockParserPlugin`,
  `BuilderRegistry`) but is less established.
- Decision: start with `flutter_markdown_plus` (direct continuation of the
  well-known `flutter_markdown`). The adapter makes future migration to
  `flutter_smooth_markdown` or any other package straightforward.

## References

- [Issue #100: Streaming Markdown](https://github.com/soliplex/flutter/issues/100)
- [flutter_markdown_plus on pub.dev](https://pub.dev/packages/flutter_markdown_plus)
- [flutter_smooth_markdown prototype diff](/Users/jaeminjo/Downloads/diff)
- [Issue #406: AI Velocity Paradox workflow](https://github.com/soliplex/soliplex/issues/406)
