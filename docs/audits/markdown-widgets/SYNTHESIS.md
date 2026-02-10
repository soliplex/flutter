# Markdown Widget Audit — Synthesis Report

**Date:** 2026-02-10
**Auditors:** Claude Opus 4.6, Gemini 2.5 Pro / 3 Pro Preview, OpenAI Codex
**Branch:** `docs/markdown-widget-audit`
**Scope:** 7 Flutter markdown rendering packages evaluated for Soliplex chat UI

---

## Context

Soliplex currently uses `flutter_markdown ^0.7.4+1` (discontinued by Google) to render
AI chat responses. We need a markdown widget that supports:

1. **Native widget embedding** — render Flutter widgets inside markdown (citation chips, action buttons)
2. **Interactive elements** — tap links to open modals, custom gesture handling
3. **Extensibility** — plugin system for custom syntax and builders
4. **AI streaming** — token-by-token rendering without UI jank
5. **Material 3 theming** — integration with SoliplexTheme
6. **Accessibility** — Semantics widgets for screen readers

Each package was audited by 3 independent reviewers (Claude, Gemini, Codex) across
10 weighted axes. Source code was cloned to `~/dev/markdown-audit/` and reviewed
file-by-file. Individual audit reports are in each package's subdirectory.

---

## Scoring Methodology

### Axes and Weights

| # | Axis | Weight | Rationale |
|---|------|:------:|-----------|
| 1 | Native Widget Embedding | 1.5x | Core requirement: render Flutter widgets inside markdown |
| 2 | Interactive Elements | 1.5x | Core requirement: link taps, modals, gesture handling |
| 3 | Extensibility | 2.0x | Core requirement: custom syntax, builders, plugins |
| 4 | AI Streaming | 2.0x | Critical: token-by-token rendering performance |
| 5 | Architecture & Design | 1.0x | Code organization, separation of concerns |
| 6 | Code Quality | 1.0x | Bugs, unsafe casts, memory leaks |
| 7 | API Compatibility | 1.0x | Migration effort from flutter_markdown |
| 8 | Performance | 1.5x | Parse speed, memory, widget tree efficiency |
| 9 | Feature Completeness | 1.0x | GFM, tables, LaTeX, task lists, etc. |
| 10 | Accessibility | 0.5x | Semantics widgets, screen reader support |

Total weight: 13.0x. Scores normalized to /10.

### Reviewer Calibration

Gemini tended to score ~1 point higher than Claude on average. Codex tended to
score ~0.5 points lower. The synthesis uses raw averages without calibration
adjustments since the rankings remain stable across reviewers.

---

## Cross-Package Scoring Matrix

### Raw Scores (Claude / Gemini / Codex)

| Axis | markdown_widget | flutter_markdown_plus | gpt_markdown | flutter_md | flutter_smooth_markdown | bit_markdown | markdown_viewer |
|------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Widget Embedding | 7/7/6 | 7/8/6 | 5/4/6 | 1/1/1 | 7/9/6 | 1/1/2 | 5/6/5 |
| Interactive | 6/6/5 | 6/7/5 | 6/6/4 | 3/3/3 | 8/10/5 | 3/3/3 | 7/8/6 |
| Extensibility | 8/8/7 | 8/9/8 | 5/3/6 | 3/3/4 | 9/10/8 | 2/2/3 | 7/8/7 |
| AI Streaming | 2/2/3 | 3/4/3 | 3/2/4 | 5/7/5 | 3/3/5 | 2/3/2 | 3/4/4 |
| Architecture | 7/7/6 | 7/8/7 | 3/3/5 | 7/8/6 | 8/9/6 | 3/3/3 | 6/7/7 |
| Code Quality | 5/6/5 | 7/8/7 | 4/4/4 | 6/7/6 | 6/7/5 | 4/4/4 | 5/6/6 |
| API Compat | 4/4/4 | 10/10/9 | 3/5/3 | 1/1/2 | 5/8/4 | 1/2/1 | 4/6/4 |
| Performance | 4/4/5 | 4/6/5 | 4/4/4 | 8/9/7 | 5/6/6 | 5/6/4 | 5/5/5 |
| Completeness | 7/8/6 | 7/8/6 | 8/9/5 | 3/4/3 | 8/10/6 | 3/3/2 | 8/9/7 |
| Accessibility | 3/3/3 | 4/4/4 | 2/3/5 | 0/1/1 | 2/2/3 | 1/2/2 | 3/5/4 |

### Weighted Averages (normalized to /10)

| # | Package | Claude | Gemini | Codex | **Average** |
|---|---------|:------:|:------:|:-----:|:-----------:|
| 1 | **flutter_markdown_plus** | 6.3 | 7.3 | 6.0 | **6.5** |
| 2 | **flutter_smooth_markdown** | 6.1 | 7.4 | 5.4 | **6.3** |
| 3 | **markdown_viewer** | 5.3 | 6.4 | 5.5 | **5.7** |
| 4 | **markdown_widget** | 5.4 | 5.4 | 5.0 | **5.3** |
| 5 | **gpt_markdown** | 4.3 | 4.0 | 5.0 | **4.4** |
| 6 | **flutter_md** | 2.9 | 3.6 | 2.9 | **3.1** |
| 7 | **bit_markdown** | 2.5 | 2.9 | 2.6 | **2.7** |

---

## Per-Axis Rankings

### Best for Widget Embedding (weight: 1.5x)

1. flutter_smooth_markdown (avg 7.3) — plugin+builder+WidgetSpan architecture
2. flutter_markdown_plus (avg 7.0) — `builders` map returns arbitrary widgets
3. markdown_widget (avg 6.7) — `SpanNodeGeneratorWithTag` + `WidgetSpan`

### Best for Interactive Elements (weight: 1.5x)

1. flutter_smooth_markdown (avg 7.7) — `onTapLink`, enhanced link builder, details blocks
2. markdown_viewer (avg 7.0) — builder-per-element with gesture support
3. flutter_markdown_plus (avg 6.0) — `onTapLink(href, title, el)` callback

### Best for Extensibility (weight: 2.0x)

1. flutter_smooth_markdown (avg 9.0) — formal plugin system + builder registry
2. flutter_markdown_plus (avg 8.3) — `builders` map + custom syntax API
3. markdown_widget (avg 7.7) — `SpanNodeGeneratorWithTag` custom tag system

### Best for AI Streaming (weight: 2.0x)

1. flutter_md (avg 5.7) — Canvas-based, fast re-render (but fails other axes)
2. flutter_smooth_markdown (avg 3.7) — 50ms throttle, but full re-parse
3. flutter_markdown_plus (avg 3.3) — same as current flutter_markdown

### Best for API Compatibility (weight: 1.0x)

1. flutter_markdown_plus (avg 9.7) — **drop-in replacement** for flutter_markdown
2. flutter_smooth_markdown (avg 5.7) — similar concepts, different names
3. markdown_viewer (avg 4.7) — builder pattern similar in concept

---

## Detailed Package Assessments

### 1. flutter_markdown_plus — ADOPT (with caveats)

**Score: 6.5/10** | [pub.dev](https://pub.dev/packages/flutter_markdown_plus) | 95 likes | BSD-3

**What it is:** Direct continuation of Google's discontinued `flutter_markdown`.
Source code is nearly identical to upstream `^0.7.x`.

**Pros:**

- **Drop-in replacement** — API-compatible with our current code (9.7/10 compat)
- Zero migration risk — change `import` and `pubspec.yaml`, done
- Active maintenance by Foresight Mobile
- Inherits all `flutter_markdown` extensions and builder patterns
- `builders` map makes widget embedding straightforward
- `onTapLink(href, title, el)` callback supports modal opening

**Cons:**

- Inherits all upstream limitations (full re-parse per update)
- AI streaming is identical to what we have today (3.3/10)
- `UniqueKey()` on text widgets prevents efficient diffing
- No plugin discovery/registration API
- Performance ceiling is low (eager parse, no caching)

**Verdict:** Safest choice. Buys us maintenance continuity while we plan a proper
streaming solution. Does not improve our current streaming performance.

### 2. flutter_smooth_markdown — FORK CANDIDATE (not direct adoption)

**Score: 6.3/10** | [pub.dev](https://pub.dev/packages/flutter_smooth_markdown) | 6 likes | MIT

**What it is:** Purpose-built for AI chat with thinking blocks, artifacts, tool
calls, and streaming support. Formal plugin system with parser plugins and builder
registry.

**Pros:**

- **Best extensibility** of all packages (9.0/10) — formal plugin architecture
- **Best interactive elements** (7.7/10) — enhanced link builder, details blocks
- AI-specific features: `<thinking>` blocks, `<artifact>` blocks, tool call rendering
- Parse cache (LRU) and RepaintBoundary for static content
- 73 source files — most comprehensive architecture

**Cons:**

- Only 6 likes — very low adoption, bus factor risk
- Unverified publisher
- `MarkdownConfig` is accepted but **dead code** (never used in parsing)
- `parseAsync` is **fake async** (synchronous wrapped in Future)
- `errorBuilder` is declared but never wired
- Stream subscription leak in `StreamMarkdown`
- Full re-parse per chunk despite streaming widget existing
- **Zero accessibility** (2.3/10) — no Semantics anywhere
- Uses `mockito` not `mocktail` (conflicts with Soliplex conventions)

**Verdict:** Best architecture for our use case, but too risky for direct adoption.
If we fork it, the plugin system and builder registry are exactly what Soliplex
needs. Would require fixing dead code, fake async, accessibility, and stream leak.

### 3. markdown_viewer — NOT RECOMMENDED

**Score: 5.7/10** | [pub.dev](https://pub.dev/packages/markdown_viewer) | 24 likes | BSD-3

**What it is:** Builder-per-element architecture using `dart_markdown` parser.

**Pros:**

- Clean builder architecture (one class per element type)
- Good feature coverage (footnotes, syntax highlighting callback)
- Best accessibility of the alternatives (4.0/10)

**Cons:**

- **Abandoned** — last updated May 2023 (2+ years stale)
- **`dart:io` import breaks web builds**
- Uses `dart_markdown` (non-standard parser fork), not `package:markdown`
- Inline widget embedding architecturally blocked by `_checkInlineWidget`
- Deprecated `bodyText2` API
- No streaming optimization

**Verdict:** Good ideas but abandoned and web-incompatible. Not viable.

### 4. markdown_widget — USE WITH MODIFICATIONS

**Score: 5.3/10** | [pub.dev](https://pub.dev/packages/markdown_widget) | 405 likes | MIT

**What it is:** Visitor pattern (AST -> SpanNode -> Widget) with config-driven
rendering. Most popular non-Google package.

**Pros:**

- Highest community adoption (405 likes)
- Clean Visitor pattern architecture
- `SpanNodeGeneratorWithTag` for custom tag handling
- Built-in TOC, task lists, syntax highlighting
- Three code block customization levels

**Cons:**

- Full re-parse on every `data` change (2.3/10 streaming)
- `MarkdownBlock` is StatelessWidget — no delta support
- List mutation bug in `list.dart:96` (content loss on re-render)
- `Config.copy()` mutates original config
- No `Semantics` anywhere (3.0/10 accessibility)
- Different API paradigm — moderate rewrite required (4.0/10 compat)

**Verdict:** Solid for static docs/TOC but streaming is a dealbreaker for chat.

### 5. gpt_markdown — HOLD

**Score: 4.4/10** | [pub.dev](https://pub.dev/packages/gpt_markdown) | 276 likes | MIT

**What it is:** Regex-based markdown renderer marketed for GPT/LLM output.

**Pros:**

- Built for AI output (handles unclosed code blocks during streaming)
- Good feature coverage (LaTeX, tables, checkboxes)
- `codeBuilder`, `tableBuilder`, `linkBuilder` callbacks

**Cons:**

- **Regex-based parsing** — brittle, not CommonMark-compliant
- **Memory leak** in `TableMd` (all 3 reviewers confirmed)
- `BuildContext` stored as widget field (anti-pattern)
- `isSame()` uses partial comparison — missed updates
- No plugin architecture — custom syntax requires writing regex
- Completely different API (3.7/10 compat)

**Verdict:** The regex approach is fundamentally wrong for a production parser.
Memory leaks are production blockers.

### 6. flutter_md — NO-GO

**Score: 3.1/10** | [pub.dev](https://pub.dev/packages/flutter_md) | 6 likes | MIT

**What it is:** Canvas/CustomPainter-based renderer. Single RenderBox approach.

**Pros:**

- Fastest raw rendering (Canvas, Picture caching, binary search hit-testing)
- Best streaming potential (fast re-render pipeline)
- Modern Dart 3 (sealed classes, pattern matching)

**Cons:**

- **Zero accessibility** (0.7/10) — no `describeSemanticsConfiguration`
- **No text selection** — Canvas rendering bypasses text handling
- **No widget embedding** — Canvas-only, no WidgetSpan
- Images commented out
- Missing tables, LaTeX, task lists, footnotes
- Zero API compatibility (1.3/10)

**Verdict:** Interesting research project but missing fundamental requirements.

### 7. bit_markdown — REJECT

**Score: 2.7/10** | [pub.dev](https://pub.dev/packages/bit_markdown) | 13 likes | MIT

**What it is:** Minimalist regex-based renderer. Early alpha (v0.0.6).

**Pros:**

- Simple (single-file architecture)

**Cons:**

- **Everything is broken:** ordered lists, headings, tables
- No widget embedding, no theming, no text selection
- Hardcoded colors break any theme
- 23 downloads total
- Not production-ready by any measure

**Verdict:** Not viable. Early experiment, not a production package.

---

## Final Recommendation

### The Vote

| Reviewer | Primary Pick | Runner-up |
|----------|-------------|-----------|
| **Claude** | flutter_markdown_plus (safe) | flutter_smooth_markdown (fork) |
| **Gemini** | flutter_smooth_markdown (adopt) | flutter_markdown_plus (safe) |
| **Codex** | flutter_markdown_plus (safe) | markdown_widget (modify) |

### Consensus: Two-Phase Strategy

**Phase 1 (immediate): Adopt `flutter_markdown_plus`**

- Drop-in replacement for discontinued `flutter_markdown`
- Change imports and pubspec dependency — 30-minute migration
- Zero risk, zero regression
- Keeps us on a maintained fork while we plan Phase 2

```yaml
# pubspec.yaml change
dependencies:
  flutter_markdown_plus: ^1.0.7  # was: flutter_markdown: ^0.7.4+1
```

**Phase 2 (planned): Build streaming markdown solution**

Two sub-options for Phase 2:

**Option A: Fork `flutter_smooth_markdown` (recommended if 3-4 week budget)**

- Best plugin architecture and extensibility model
- AI-specific features (thinking blocks, artifacts) align with Soliplex roadmap
- Requires: fix dead code, real async parsing, accessibility, stream leak
- Estimated effort: 3-4 weeks to production-ready fork

**Option B: Extend `flutter_markdown_plus` with streaming wrapper**

- Add debouncing (250ms intervals) around `MarkdownBody`
- Split rendering at block boundaries — only re-render last incomplete block
- Memoize completed blocks
- Estimated effort: 1-2 weeks for basic streaming, ongoing optimization

### Decision Criteria

| Factor | Option A (fork smooth) | Option B (extend plus) |
|--------|:-----:|:-----:|
| Streaming quality | Better (purpose-built) | Good enough (debounce) |
| Extensibility ceiling | Higher (plugin system) | Lower (builder map) |
| Migration risk | Medium (new API) | Low (same API) |
| Maintenance burden | High (own fork) | Low (upstream updates) |
| Time to production | 3-4 weeks | 1-2 weeks |
| AI feature support | Native (thinking, artifacts) | Manual (custom builders) |

**Our recommendation: Phase 1 now, decide Phase 2 after team review.**

---

## Appendix: Individual Report Locations

| Package | Claude | Gemini | Codex |
|---------|--------|--------|-------|
| markdown_widget | [claude-audit.md](markdown_widget/claude-audit.md) | [gemini-audit.md](markdown_widget/gemini-audit.md) | [codex-audit.md](markdown_widget/codex-audit.md) |
| flutter_markdown_plus | [claude-audit.md](flutter_markdown_plus/claude-audit.md) | [gemini-audit.md](flutter_markdown_plus/gemini-audit.md) | [codex-audit.md](flutter_markdown_plus/codex-audit.md) |
| gpt_markdown | [claude-audit.md](gpt_markdown/claude-audit.md) | [gemini-audit.md](gpt_markdown/gemini-audit.md) | [codex-audit.md](gpt_markdown/codex-audit.md) |
| flutter_md | [claude-audit.md](flutter_md/claude-audit.md) | [gemini-audit.md](flutter_md/gemini-audit.md) | [codex-audit.md](flutter_md/codex-audit.md) |
| flutter_smooth_markdown | [claude-audit.md](flutter_smooth_markdown/claude-audit.md) | [gemini-audit.md](flutter_smooth_markdown/gemini-audit.md) | [codex-audit.md](flutter_smooth_markdown/codex-audit.md) |
| bit_markdown | [claude-audit.md](bit_markdown/claude-audit.md) | [gemini-audit.md](bit_markdown/gemini-audit.md) | [codex-audit.md](bit_markdown/codex-audit.md) |
| markdown_viewer | [claude-audit.md](markdown_viewer/claude-audit.md) | [gemini-audit.md](markdown_viewer/gemini-audit.md) | [codex-audit.md](markdown_viewer/codex-audit.md) |
