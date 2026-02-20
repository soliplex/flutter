# Implementation Plan: Markdown Renderer

## Overview

This plan uses vertical slicing with a walking skeleton approach. Slice 1
delivers the adapter abstraction and package swap with identical behavior.
Subsequent slices add features one at a time.

## Slice Summary

| # | Slice | ~Lines | Customer Value |
|---|-------|--------|----------------|
| 1 | Adapter + package swap | ~120 | Swappable foundation, same behavior |
| 2 | Theme extension | ~100 | Markdown styled by app theme system |
| 3 | HTML sanitization | ~40 | Clean rendering, no stray HTML tags |
| 4 | Clickable links | ~60 | Users can tap links in AI responses |
| 5 | Code fences with copy | ~80 | Copy button on every code block |
| 6 | Fullscreen image viewer | ~150 | Tap image → zoom/pan/rotate overlay |
| 7 | Custom block registration | ~120 | Plugin system for native widget blocks |
| 8 | Streaming performance | ~100 | Incremental parsing for long responses |

## Dependency Structure

```text
[1] Adapter + package swap
         │
    ┌────┼────────────┐
    ▼    ▼            ▼
[2] Theme  [3] HTML  [4] Links
    │
    ▼
[5] Code copy
    │
    ▼
[6] Images ────► [7] Custom blocks
                       │
                       ▼
                 [8] Streaming
```

**After slice 1:** Slices 2, 3, and 4 are independent of each other.
**Slice 5** benefits from 2 (themed code blocks).
**Slice 6** depends on 1 only but is sequenced later due to size.
**Slice 7** depends on understanding the builder pattern from slice 5.
**Slice 8** can be done anytime after slice 1 but is deferred.

## Implementation Order

1. **Slice 1** — Adapter + package swap (required first)
2. **Slice 2** — Theme extension
3. **Slice 3** — HTML sanitization (parallel with 4)
4. **Slice 4** — Clickable links (parallel with 3)
5. **Slice 5** — Code fences with copy
6. **Slice 6** — Fullscreen image viewer
7. **Slice 7** — Custom block registration
8. **Slice 8** — Streaming performance (deferred)

---

## Slice 1: Adapter + Package Swap

**Branch:** `feat/markdown/01-adapter`

**Target:** ~120 lines

**Customer value:** Same rendering behavior, but the markdown package is now
behind a swappable adapter. Foundation for all subsequent slices.

### Tasks

1. Create `lib/shared/widgets/markdown/markdown_renderer.dart` — abstract
   widget with `data`, `onLinkTap`, `onImageTap`, `blockExtensions`
2. Create `lib/shared/widgets/markdown/markdown_block_extension.dart` — custom
   block type definition
3. Create `lib/shared/widgets/markdown/flutter_markdown_plus_renderer.dart` —
   concrete implementation using `MarkdownBody`
4. Move `code_block_builder.dart` from `features/chat/widgets/` to
   `shared/widgets/markdown/`
5. Update `pubspec.yaml`: replace `flutter_markdown` with
   `flutter_markdown_plus`
6. Update `chat_message_widget.dart` to use `MarkdownRenderer` instead of
   `MarkdownBody` directly
7. Update imports in moved/changed files
8. Write tests for the adapter

### Files Created

- `lib/shared/widgets/markdown/markdown_renderer.dart`
- `lib/shared/widgets/markdown/markdown_block_extension.dart`
- `lib/shared/widgets/markdown/flutter_markdown_plus_renderer.dart`
- `test/shared/widgets/markdown/flutter_markdown_plus_renderer_test.dart`

### Files Modified

- `pubspec.yaml` (swap dependency)
- `lib/features/chat/widgets/chat_message_widget.dart` (use adapter)

### Files Moved

- `lib/features/chat/widgets/code_block_builder.dart` →
  `lib/shared/widgets/markdown/code_block_builder.dart`

### Tests

- Widget: Renders markdown text as widgets
- Widget: Passes data to underlying MarkdownBody
- Widget: CodeBlockBuilder still produces syntax-highlighted code
- Unit: Existing chat_message_widget tests still pass

### Acceptance Criteria

- [ ] Abstract `MarkdownRenderer` widget created
- [ ] Concrete `FlutterMarkdownPlusRenderer` created
- [ ] `flutter_markdown_plus` in pubspec, `flutter_markdown` removed
- [ ] `ChatMessageWidget` uses `MarkdownRenderer`
- [ ] No file imports `flutter_markdown_plus` except the concrete renderer and
      its builder
- [ ] All existing tests pass
- [ ] `mcp__dart__analyze_files` reports 0 issues

---

## Slice 2: Theme Extension

**Branch:** `feat/markdown/02-theme`

**Target:** ~100 lines

**Customer value:** Markdown styling is driven by the app's theme system.
Changing the theme changes markdown appearance automatically.

### Tasks

1. Create `lib/shared/widgets/markdown/markdown_theme_extension.dart`
2. Define `MarkdownThemeExtension` with styles for headings, body, code, links,
   blockquote, table
3. Implement `toMarkdownStyleSheet()` adapter method
4. Implement `copyWith()` and `lerp()` for theme transitions
5. Register the extension in the app's `ThemeData`
6. Update `FlutterMarkdownPlusRenderer` to read theme from context
7. Remove inline `MarkdownStyleSheet` construction from
   `ChatMessageWidget`

### Files Created

- `lib/shared/widgets/markdown/markdown_theme_extension.dart`
- `test/shared/widgets/markdown/markdown_theme_extension_test.dart`

### Files Modified

- `lib/shared/widgets/markdown/flutter_markdown_plus_renderer.dart`
- `lib/design/` (register extension in theme)
- `lib/features/chat/widgets/chat_message_widget.dart` (remove inline styles)

### Tests

- Unit: `toMarkdownStyleSheet()` maps all fields correctly
- Unit: `copyWith()` overrides specified fields
- Unit: `lerp()` interpolates between two extensions
- Widget: Markdown renders with theme-provided styles

### Acceptance Criteria

- [ ] `MarkdownThemeExtension` created with all style fields
- [ ] Extension registered in app's `ThemeData`
- [ ] `FlutterMarkdownPlusRenderer` reads theme from context
- [ ] Inline style construction removed from `ChatMessageWidget`
- [ ] All tests pass

---

## Slice 3: HTML Sanitization

**Branch:** `feat/markdown/03-html-sanitization`

**Target:** ~40 lines

**Customer value:** Stray HTML tags like `<br />` no longer appear as literal
text in AI responses.

### Tasks

1. Add `_sanitize()` method to `FlutterMarkdownPlusRenderer`
2. Replace `<br>`, `<br />`, `<br/>` with newlines
3. Add tests for sanitization

### Files Modified

- `lib/shared/widgets/markdown/flutter_markdown_plus_renderer.dart`
- Tests

### Tests

- Unit: `<br>` replaced with newline
- Unit: `<br />` replaced with newline
- Unit: `<br/>` replaced with newline
- Unit: Content without HTML passes through unchanged
- Widget: Rendered output shows newlines, not HTML tags

### Acceptance Criteria

- [ ] Stray `<br>` variants are replaced with newlines
- [ ] No HTML tags render as visible text
- [ ] All tests pass

---

## Slice 4: Clickable Links

**Branch:** `feat/markdown/04-links`

**Target:** ~60 lines

**Customer value:** Users can tap links in AI responses to open them.

### Tasks

1. Wire `onTapLink` in `FlutterMarkdownPlusRenderer` to the adapter's
   `onLinkTap` callback
2. In `ChatMessageWidget`, provide an `onLinkTap` handler that opens URLs
   (use `url_launcher` or in-app browser)
3. Style links via theme extension (add link color/decoration if not already
   present)
4. Add tests

### Files Modified

- `lib/shared/widgets/markdown/flutter_markdown_plus_renderer.dart`
- `lib/features/chat/widgets/chat_message_widget.dart`
- Tests

### Tests

- Widget: Tapping a link calls `onLinkTap` with correct href
- Widget: Links are visually styled (color, underline)
- Integration: Link tap triggers URL opening

### Acceptance Criteria

- [ ] Links in AI responses are tappable
- [ ] Tap opens URL via `url_launcher`
- [ ] Links are visually distinguishable
- [ ] All tests pass

---

## Slice 5: Code Fences with Copy Button

**Branch:** `feat/markdown/05-code-copy`

**Target:** ~80 lines

**Customer value:** Each code block in an AI response has a copy button.

### Tasks

1. Update `CodeBlockBuilder` to include a copy-to-clipboard button
2. Position button in top-right corner of code block
3. Show language label if detected
4. Copy the code content on tap, show snackbar confirmation
5. Style the button and code block header via theme
6. Add tests

### Files Modified

- `lib/shared/widgets/markdown/code_block_builder.dart`
- Tests

### Tests

- Widget: Code block renders with copy button
- Widget: Tapping copy button copies code to clipboard
- Widget: Language label shown when language is detected
- Widget: Snackbar shown after copy

### Acceptance Criteria

- [ ] Copy button visible on every code fence
- [ ] Tap copies code content to clipboard
- [ ] Confirmation snackbar shown
- [ ] Language label displayed when detected
- [ ] All tests pass

---

## Slice 6: Fullscreen Image Viewer

**Branch:** `feat/markdown/06-images`

**Target:** ~150 lines

**Customer value:** Users can tap images in AI responses to view fullscreen
with zoom, pan, and rotate.

### Tasks

1. Create `lib/shared/widgets/fullscreen_image_viewer.dart`
2. Implement `InteractiveViewer` with zoom, pan support
3. Add rotation gesture support
4. Add close button / back navigation
5. Wire `imageBuilder` in `FlutterMarkdownPlusRenderer` to render tappable
   images
6. In `ChatMessageWidget`, provide `onImageTap` handler that navigates to
   fullscreen viewer
7. Constrain inline image size (max width 50% of screen, max height 400px)
8. Add tests

### Files Created

- `lib/shared/widgets/fullscreen_image_viewer.dart`
- `test/shared/widgets/fullscreen_image_viewer_test.dart`

### Files Modified

- `lib/shared/widgets/markdown/flutter_markdown_plus_renderer.dart`
- `lib/features/chat/widgets/chat_message_widget.dart`
- Tests

### Tests

- Widget: Images render inline with constrained size
- Widget: Tapping image calls `onImageTap` with correct src
- Widget: Fullscreen viewer opens with zoom/pan
- Widget: Close button returns to chat
- Widget: Error state shown for broken image URLs

### Acceptance Criteria

- [ ] Images render inline with size constraints
- [ ] Tap opens fullscreen viewer
- [ ] Viewer supports pinch-to-zoom and drag-to-pan
- [ ] Rotation support
- [ ] Close/back returns to chat
- [ ] Broken image URLs show error state
- [ ] All tests pass

---

## Slice 7: Custom Block Registration

**Branch:** `feat/markdown/07-custom-blocks`

**Target:** ~120 lines

**Customer value:** Custom markdown syntax (e.g., `[[map: lat, lng]]`) renders
as native widgets.

### Tasks

1. Implement `MarkdownBlockExtension` translation in the concrete adapter
2. For each registered extension, create a `BlockSyntax` subclass from the
   pattern and a `MarkdownElementBuilder` from the builder function
3. Wire `blockSyntaxes` and `builders` parameters in the adapter
4. Create a sample map block extension as a proof of concept
5. Add tests

### Files Modified

- `lib/shared/widgets/markdown/flutter_markdown_plus_renderer.dart`
- `lib/shared/widgets/markdown/markdown_block_extension.dart`
- Tests

### Files Created

- `test/shared/widgets/markdown/markdown_block_extension_test.dart`

### Tests

- Unit: Extension pattern matches expected syntax
- Widget: Registered block renders custom widget
- Widget: Unregistered blocks render as plain text
- Widget: Multiple extensions can be registered simultaneously
- Integration: Map block syntax renders a widget with correct lat/lng

### Acceptance Criteria

- [ ] `MarkdownBlockExtension` translated to package types in adapter
- [ ] Custom blocks render as native widgets
- [ ] Consumers register blocks without importing package types
- [ ] Multiple extensions work simultaneously
- [ ] All tests pass

---

## Slice 8: Streaming Performance

**Branch:** `feat/markdown/08-streaming`

**Target:** ~100 lines

**Customer value:** Long AI responses render smoothly during streaming without
UI jank.

### Tasks

1. Profile current rendering performance with long markdown responses
2. Implement block-level caching — cache widget tree for completed markdown
   blocks (separated by blank lines), only re-parse trailing incomplete block
3. Add debounce for re-parsing during rapid delta delivery
4. Add tests

### Files Modified

- `lib/shared/widgets/markdown/flutter_markdown_plus_renderer.dart`
- Tests

### Implementation Notes

Current behavior: every text delta triggers full markdown re-parse of the
accumulated string. For long responses this scales poorly.

Optimization approach:

- Split markdown at block boundaries (double newlines)
- Cache rendered widgets for completed blocks (text hasn't changed)
- Only re-parse the trailing incomplete block on each delta
- Optional: debounce re-parse at 100ms intervals during rapid streaming

### Tests

- Unit: Completed blocks are cached across rebuilds
- Unit: Only trailing block re-parses on delta
- Widget: Long streaming response renders without frame drops
- Widget: Cached blocks produce identical output to full re-parse

### Acceptance Criteria

- [ ] Completed markdown blocks are cached
- [ ] Only trailing block re-parses during streaming
- [ ] No visual difference from full re-parse
- [ ] Measurable performance improvement on long responses
- [ ] All tests pass

---

## Branch Naming Convention

| Slice | Branch |
|-------|--------|
| 1 | `feat/markdown/01-adapter` |
| 2 | `feat/markdown/02-theme` |
| 3 | `feat/markdown/03-html-sanitization` |
| 4 | `feat/markdown/04-links` |
| 5 | `feat/markdown/05-code-copy` |
| 6 | `feat/markdown/06-images` |
| 7 | `feat/markdown/07-custom-blocks` |
| 8 | `feat/markdown/08-streaming` |

## Critical Files

**Created:**

- `lib/shared/widgets/markdown/markdown_renderer.dart` — Abstract widget
  (slice 1)
- `lib/shared/widgets/markdown/flutter_markdown_plus_renderer.dart` — Concrete
  adapter (slice 1, modified in 2-7)
- `lib/shared/widgets/markdown/markdown_theme_extension.dart` — ThemeExtension
  (slice 2)
- `lib/shared/widgets/markdown/markdown_block_extension.dart` — Custom block
  type (slice 1, wired in 7)
- `lib/shared/widgets/fullscreen_image_viewer.dart` — Image viewer (slice 6)

**Modified:**

- `lib/features/chat/widgets/chat_message_widget.dart` — Use adapter
  (slice 1), add callbacks (slices 4, 6)
- `lib/design/` — Register theme extension (slice 2)
- `pubspec.yaml` — Swap package (slice 1)

**Moved:**

- `code_block_builder.dart` — From `features/chat/widgets/` to
  `shared/widgets/markdown/` (slice 1, enhanced in slice 5)

## Definition of Done (per slice)

- [ ] All tasks completed
- [ ] All tests written and passing (TDD)
- [ ] Code formatted (`mcp__dart__dart_format`)
- [ ] No analyzer issues (`mcp__dart__analyze_files`)
- [ ] Coverage >= 85%
- [ ] PR reviewed and approved
- [ ] Merged to main

## Verification Checklist (end state)

1. `flutter_markdown_plus` is the only markdown package in pubspec
2. No file outside `shared/widgets/markdown/` imports the package
3. Theme drives all markdown styles
4. Links open in browser
5. Code fences have copy buttons
6. Images open fullscreen with zoom/pan/rotate
7. No stray HTML renders
8. Custom blocks render as native widgets
9. Streaming remains smooth for long responses
