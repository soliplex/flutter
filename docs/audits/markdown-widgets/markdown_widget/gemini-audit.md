# markdown_widget - Gemini Pro 3 Audit

**Model:** gemini-3-pro-preview
**Files Analyzed:** 17 source files (full lib/ directory)

## Soliplex Requirements Scoring

| # | Axis | Score | Notes |
|---|------|:-----:|-------|
| 1 | Native Widget Embedding | 7/10 | `WidgetSpan` used in code blocks and images. Custom `SpanNode` subclasses can return any `WidgetSpan`. `PreConfig.builder`, `ImgConfig.builder` accept arbitrary widgets. Mid-paragraph embedding requires custom node work. |
| 2 | Interactive Elements | 6/10 | `LinkConfig.onTap` intercepts link clicks. `_toLinkInlineSpan` adds `TapGestureRecognizer`. No built-in support for custom interactive zones beyond links. |
| 3 | Extensibility | 8/10 | `SpanNodeGeneratorWithTag` + `TextNodeGenerator` + `RichTextBuilder` provide comprehensive extension points. LaTeX extension pattern documented. |
| 4 | AI Streaming | 2/10 | **Critical.** Full re-parse + re-build on every update. No incremental/delta support. 10-50 rebuilds/sec during streaming. |
| 5 | Architecture & Design | 7/10 | Clean Visitor pattern (AST -> SpanNode -> Widget). Decision to pre-generate full widget list defeats ListView.builder lazy loading. |
| 6 | Code Quality | 6/10 | Unsafe casts (`code_block.dart:28`), mutable visitor state, loose typing. Generally readable naming. |
| 7 | API Compatibility | 4/10 | Completely different API paradigm from `flutter_markdown`. `builders` -> `SpanNodeGeneratorWithTag`. `MarkdownStyleSheet` -> `MarkdownConfig`. Full rewrite required. |
| 8 | Performance | 4/10 | **Critical.** Eager full parse in initState. VisibilityDetector on every item. Synchronous main thread parsing. No caching. |
| 9 | Feature Completeness | 8/10 | Full GFM, tables, task lists, syntax highlighting, TOC. No native LaTeX (extension only). |
| 10 | Accessibility | 3/10 | No semantic labels on any elements. No `Semantics` widgets. Would need manual addition. |

**Weighted Total: 5.4/10** (using Soliplex weights)

## Key Findings

### Architecture

- Pre-computed `_widgets` list (`markdown.dart:56`) means memory scales linearly with document length at load time
- `ListView.builder` is used but items are pre-instantiated, negating lazy construction benefits

### Native Widget Embedding Assessment

- `WidgetSpan` is the mechanism: code blocks (`code_block.dart:83`), images (`img.dart:45`) both use it
- Custom nodes via `SpanNodeGeneratorWithTag` can return `WidgetSpan(child: anyWidget)`
- `PreConfig.builder` typedef: `Widget Function(String code, String language)` - full control over code rendering
- **Gap:** No first-class "widget builder map" like flutter_markdown's `builders` parameter

### Interactive Elements Assessment

- `LinkConfig.onTap`: `ValueCallback<String>?` intercepts link clicks (`link.dart:48`)
- `_toLinkInlineSpan` (`link.dart:61`) recursively adds `TapGestureRecognizer` to TextSpans and wraps WidgetSpans in `InkWell`
- **Gap:** No generic "on element tap" callback. Custom interactive elements require custom `SpanNode` subclasses with their own gesture handling.

### Performance Red Flags

- Every block element wrapped in `VisibilityDetector` (`markdown.dart:137`) - expensive layout callbacks on scroll
- `buildWidgets()` runs synchronously on main thread (`markdown.dart:86`) - 50KB markdown will freeze UI
- Full re-parse on `didUpdateWidget` (`markdown.dart:160-164`)

### Correctness Issues

- `children.removeAt(0)` in `list.dart` mutates node tree during build
- `MarkdownConfig.copy()` mutates internal state of source config
- `double.parse` in image attributes without try/catch
- `launchUrl(Uri.parse(url))` without validation or error handling

### Streaming Assessment

If streaming text token-by-token at 10-50 tokens/sec:

1. Full re-parse runs on every token
2. Entire widget list rebuilt
3. Scroll position lost
4. CPU pegged, UI stutter guaranteed

### Recommended Mitigations (if adopting)

1. Disable TOC for streaming views
2. Debounce data updates to 2-4 Hz max
3. Move parsing to isolate
4. Fix list mutation bug
5. Patch unsafe casts in code_block.dart
