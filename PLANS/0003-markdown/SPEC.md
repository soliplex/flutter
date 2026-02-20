# Feature Specification: Streaming Markdown Renderer

## Overview

Replace the current `flutter_markdown` integration with `flutter_markdown_plus`
behind a swappable adapter, and implement the full set of markdown rendering
features required for AI chat responses.

## Problem Statement

The current markdown rendering in `ChatMessageWidget` is tightly coupled to
`flutter_markdown` and lacks critical features:

- **No link handling:** Users cannot click href links in AI responses.
- **No theme participation:** Markdown styles are hardcoded per-widget rather
  than driven by the app's theme system.
- **No image interaction:** Images in markdown are rendered inline with no tap
  handling, zoom, or fullscreen support.
- **No copy button on code fences:** Users must manually select code to copy.
- **Stray HTML rendered as text:** Tags like `<br />` appear literally.
- **No extensibility:** Cannot replace markdown blocks with native widgets
  (e.g., GPS coordinates → map).
- **Tight coupling:** Only two files import `flutter_markdown`, but there is no
  abstraction — swapping packages requires understanding the widget internals.

**Issue:** <https://github.com/soliplex/flutter/issues/100>

**Current integration points (2 files):**

- `lib/features/chat/widgets/chat_message_widget.dart` — uses `MarkdownBody`
  directly
- `lib/features/chat/widgets/code_block_builder.dart` — extends
  `MarkdownElementBuilder`

## Requirements

### Functional Requirements

1. Markdown rendering is abstracted behind an adapter widget that makes package
   swaps a 3-file change (concrete renderer, theme adapter method, pubspec).
2. The app shell plumbs theme through to markdown via a `ThemeExtension`.
3. Users can click links in AI responses. The app decides whether to open
   in-app browser or external browser.
4. Each code fence in a response has a "copy to clipboard" button.
5. Users can tap images to open a fullscreen viewer with zoom, pan, and rotate.
6. Stray HTML (`<br />`, `<br>`, `<br/>`) is filtered and does not render.
7. Custom markdown block types can be registered to render as native widgets
   (e.g., `[[map: lat, lng]]` → Google Maps widget).

### Non-Functional Requirements

- The adapter abstraction adds no runtime overhead (it IS a widget, not a
  wrapper around one).
- `flutter_markdown_plus` is never imported outside the concrete adapter and
  its supporting files.
- Theme extension follows the existing `SoliplexTheme` pattern.
- Custom block registration is decoupled from the markdown package's types.

## Use Cases

### Use Case 1: Click a Link

1. Alice reads an AI response containing `[Flutter docs](https://flutter.dev)`.
2. Alice taps the link.
3. The app opens the URL in the in-app browser.

### Use Case 2: Copy a Code Block

1. Bob reads an AI response with a Dart code snippet.
2. Bob taps the copy button on the code fence.
3. The code is copied to the clipboard.
4. A snackbar confirms "Copied to clipboard".

### Use Case 3: View an Image Fullscreen

1. Carol reads an AI response containing an inline image.
2. Carol taps the image.
3. A fullscreen overlay opens showing the image.
4. Carol can pinch to zoom, drag to pan, and rotate.
5. Carol taps close (or back) to return to the chat.

### Use Case 4: Stray HTML Filtered

1. The AI responds with `Here is a break<br />and more text`.
2. The user sees "Here is a break" followed by a newline, not the literal
   `<br />` tag.

### Use Case 5: Custom Map Block

1. The AI responds with `[[map: 30.2672, -97.7431]]`.
2. The markdown renderer matches this to a registered map block extension.
3. An interactive Google Maps widget renders inline showing Austin, TX.

### Use Case 6: Swap Markdown Package

1. A developer decides to replace `flutter_markdown_plus` with a new package.
2. They write a new concrete renderer implementing the abstract widget's
   contract.
3. They update `toMarkdownStyleSheet()` in the theme extension for the new
   package's style types.
4. They update `pubspec.yaml`.
5. No other files change. All consumers, callbacks, themes, and custom blocks
   continue to work.

## Design

### Architecture

```text
┌──────────────────────────────────────────────────────────────────┐
│                           Consumers                               │
│  ┌──────────────────┐  ┌──────────────────────────────────────┐   │
│  │ ChatMessageWidget│  │ Any future markdown consumer         │   │
│  └────────┬─────────┘  └────────────┬─────────────────────────┘   │
│           │                         │                             │
│           │ uses MarkdownRenderer   │                             │
│           ▼                         ▼                             │
├──────────────────────────────────────────────────────────────────┤
│                    Abstraction Layer                               │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  MarkdownRenderer (abstract StatelessWidget)                 │ │
│  │  - data: String                                              │ │
│  │  - onLinkTap: callback                                       │ │
│  │  - onImageTap: callback                                      │ │
│  │  - blockExtensions: Map<String, MarkdownBlockExtension>      │ │
│  └──────────────────────────────────────────────────────────────┘ │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  MarkdownThemeExtension (ThemeExtension)                     │ │
│  │  - heading, body, code, link styles                          │ │
│  │  - toMarkdownStyleSheet() — package-specific adapter method  │ │
│  └──────────────────────────────────────────────────────────────┘ │
├──────────────────────────────────────────────────────────────────┤
│                    Concrete Implementation                         │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  FlutterMarkdownPlusRenderer                                 │ │
│  │  - Imports flutter_markdown_plus (only file that does)       │ │
│  │  - Translates callbacks to package API                       │ │
│  │  - Sanitizes HTML                                            │ │
│  │  - Wires up CodeBlockBuilder, imageBuilder, onTapLink        │ │
│  └──────────────────────────────────────────────────────────────┘ │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  CodeBlockBuilder (MarkdownElementBuilder)                   │ │
│  │  - Syntax highlighting via flutter_highlight                 │ │
│  │  - Copy button per code fence                                │ │
│  └──────────────────────────────────────────────────────────────┘ │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  FullscreenImageViewer                                       │ │
│  │  - InteractiveViewer with zoom, pan, rotate                  │ │
│  └──────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

### Key Components

**MarkdownRenderer:** Abstract `StatelessWidget` defining the public contract.
Consumers depend on this type. Never imports a markdown package.

**MarkdownThemeExtension:** A `ThemeExtension<MarkdownThemeExtension>` that
maps app design tokens to markdown styles. Contains one package-specific adapter
method (`toMarkdownStyleSheet()`) — the only code that knows both the app's
theme and the package's style types.

**FlutterMarkdownPlusRenderer:** Concrete implementation. The only file that
imports `flutter_markdown_plus`. Translates the abstract contract into
package-specific API calls.

**CodeBlockBuilder:** Extends `MarkdownElementBuilder` from
`flutter_markdown_plus`. Renders syntax-highlighted code with a copy button.
Package-specific — lives alongside the concrete renderer.

**FullscreenImageViewer:** Standalone widget for fullscreen image viewing with
`InteractiveViewer`. Not package-specific — reusable.

### Custom Block Extensions

Custom blocks are registered through an abstraction that doesn't leak package
types:

```dart
class MarkdownBlockExtension {
  final RegExp pattern;
  final String tag;
  final Widget Function(String content, Map<String, String> attributes) builder;
}
```

The concrete adapter translates each extension into the package's
`BlockSyntax` + `MarkdownElementBuilder` pair.

## Acceptance Criteria

- [ ] Markdown package is swappable by changing 3 files (renderer, theme
      adapter, pubspec).
- [ ] `flutter_markdown_plus` is never imported outside the concrete adapter.
- [ ] Theme extension drives all markdown styles from the app's design system.
- [ ] Links are tappable and open in-app browser.
- [ ] Each code fence has a working copy button.
- [ ] Images are tappable and open fullscreen with zoom/pan/rotate.
- [ ] Stray HTML (`<br>`, `<br />`, `<br/>`) does not render.
- [ ] Custom block types can be registered without importing package types.
- [ ] All existing tests pass or are updated appropriately.
