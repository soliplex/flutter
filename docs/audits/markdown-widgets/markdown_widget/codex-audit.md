# markdown_widget - Codex Audit

**Model:** OpenAI Codex
**Scope:** Full lib/ directory audit

## Soliplex Requirements Scoring

| # | Axis | Score | Notes |
|---|------|:-----:|-------|
| 1 | Native Widget Embedding | 6/10 | `WidgetSpan` used in code blocks and images. Custom `SpanNode` subclasses can embed widgets. Tight coupling to `TextSpan` limits non-text block extensibility. |
| 2 | Interactive Elements | 5/10 | `LinkConfig.onTap` for link interception. No generic tap/interaction API for other elements. Custom interactive elements need custom `SpanNode` with own gesture handling. |
| 3 | Extensibility | 7/10 | Custom tag generators work well. Tight coupling to widget rendering and reliance on `TextSpan` reduces extensibility for async/streaming renderers. |
| 4 | AI Streaming | 3/10 | Full clear + re-parse on every update. No chunking or incremental support. |
| 5 | Architecture & Design | 6/10 | Good separation (parse/traverse/render) but render nodes tightly coupled to Flutter widgets and mutable state. |
| 6 | Code Quality | 5/10 | List mutation during build (`list.dart:96`), image parsing crashes, link launching lacks validation. |
| 7 | API Compatibility | 4/10 | Completely different paradigm from flutter_markdown. `builders` -> `SpanNodeGeneratorWithTag`. Full rewrite. |
| 8 | Performance | 5/10 | Eager parse, VisibilityDetector on every item, syntax highlighting re-parses each code line. |
| 9 | Feature Completeness | 6/10 | Core elements covered. No HTML blocks, footnotes, or interactive task lists. |
| 10 | Accessibility | 3/10 | No semantic labels. No `Semantics` widgets anywhere. |

**Weighted Total: 5.0/10** (using Soliplex weights)

## Red Flags

1. **List mutation bug** (`list.dart:96`): `children.removeAt(0)` during build - content loss on re-render
2. **Config.copy side effect** (`configs.dart:185`): Mutates original config's internal map
3. **Image parsing crash** (`img.dart:16`): `double.parse` without try/catch on user-provided attributes
4. **Link validation missing** (`link.dart:32`): `launchUrl(Uri.parse(url))` - invalid schemes crash
5. **Dead API** (`img.dart:72`): `ImgConfig.errorBuilder` exists but is never used

## Native Widget Embedding Assessment

- Possible via custom `SpanNode` returning `WidgetSpan(child: anyWidget)`
- `PreConfig.builder`, `ImgConfig.builder` demonstrate the pattern
- No first-class "builders" map API - must use `SpanNodeGeneratorWithTag`
- Tight coupling to `TextSpan`/`InlineSpan` tree makes complex widget embedding awkward

## Overall Recommendation

Core rendering pipeline is solid but correctness issues and streaming limitations are significant. For Soliplex's needs (widget embedding, interactions, streaming), this package would require substantial wrapper code and bug fixes.
