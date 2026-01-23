# Soliplex Frontend

Cross-platform Flutter frontend for Soliplex AI-powered RAG system.

## Quick Reference

Use Dart MCP server tools instead of shell commands:

- **Run tests:** `mcp__dart__run_tests` (must pass)
- **Analyze:** `mcp__dart__analyze_files` (must be 0 issues)
- **Format:** `mcp__dart__dart_format`
- **Install deps:** `mcp__dart__pub` with command `get`
- **Run app:** `mcp__dart__launch_app` with device from `mcp__dart__list_devices`
- **Lint markdown:** `npx markdownlint-cli "**/*.md"` (shell command)

## Project Structure

```text
lib/
├── core/                    # Infrastructure layer
│   ├── models/              # ActiveRunState, AppConfig
│   ├── providers/           # Riverpod providers (7)
│   └── router/              # GoRouter configuration
├── features/                # Feature screens
│   ├── chat/                # Message display and input
│   ├── history/             # Thread list sidebar
│   ├── thread/              # Main chat view (dual-panel)
│   ├── room/                # Room threads view
│   └── ...                  # home, rooms, settings, login
├── shared/                  # Reusable widgets and utilities
└── main.dart                # Entry point

packages/
├── soliplex_client/         # Pure Dart: REST API, AG-UI protocol
└── soliplex_client_native/  # Platform HTTP adapters (Cupertino)

docs/                        # Documentation (see index.md)
```

## Architecture

**Three Layers:**

1. UI Components - Feature screens and widgets
2. Core Frontend - Riverpod providers, navigation, AG-UI processing
3. soliplex_client - Pure Dart package (no Flutter dependency)

**Patterns:**

- Repository: SoliplexApi for backend communication
- Factory: createPlatformClient() for HTTP clients
- Observer: HttpObserver for request/response monitoring
- Buffer: TextMessageBuffer, ToolCallBuffer for streaming

**State Management:**

- Riverpod (manual providers, no codegen)
- ActiveRunNotifier orchestrates AG-UI streaming
- RunContext persists thread/run state

**UI Component Scopes:**

- History → Room scope (thread list, auto-selection)
- Chat → Thread scope (messages, streaming, input)
- HttpInspector → Request/response traffic monitoring

## Development Rules

- KISS, YAGNI, SOLID - simple solutions over clever ones
- Edit existing files; don't create new ones without need
- Match surrounding code style exactly
- Prefer editing over rewriting implementations
- Fix broken things immediately when found

## Code Quality

**After any code modification, run these checks:**

1. **Format:** `mcp__dart__dart_format` (formats files in place)
2. **Analyze:** `mcp__dart__analyze_files` (must be 0 issues)
3. **Test:** `mcp__dart__run_tests` (targeted tests during dev, full suite before commit)
4. **Coverage:** Verify coverage is at least 85%

Warnings indicate real bugs. Fix all errors, warnings, AND hints immediately.

**Never use `// ignore:` directives.** Restructure code to eliminate the warning instead
of suppressing it. If a warning seems unavoidable, it usually means the code design
needs rethinking.

**Coverage target:** 85%+

## Testing

**Context-aware test running:**

- **Targeted tests:** Run directly for files you modified (e.g., specific test file paths)
- **Full test suite:** Ask the user to run it and report results back to preserve context

The full test suite output is verbose and consumes significant context. When you need
to verify all tests pass (e.g., before commit), prompt:

> "Please run the full test suite and let me know if there are any failures."

**Helpers** (test/helpers/test_helpers.dart):

- `MockSoliplexApi` - API mock for widget tests
- `TestData` - Factory for test fixtures
- `pumpWithProviders()` - Wraps widgets with required providers

**Patterns:**

- Mirror lib/ structure in test/
- Unit tests for models and providers
- Widget tests for UI components

## Configuration

- `pubspec.yaml` - Dependencies
- `analysis_options.yaml` - Dart analyzer (very_good_analysis)
- `.markdownlint.json` - Markdown linting rules

## Critical Rules

1. Always refer to, and abide by `docs/rules/flutter_rules.md`
2. Run `mcp__dart__dart_format` then verify with `dart format --set-exit-if-changed .`
3. `mcp__dart__analyze_files` MUST report 0 errors AND 0 warnings
4. `mcp__dart__run_tests` must pass before changes are complete
5. Keep `soliplex_client` pure Dart (no Flutter imports)
6. Platform-specific code goes in `soliplex_client_native`
7. New Flutter/Dart packages need a `.gitignore` (see <https://github.com/flutter/flutter/blob/master/.gitignore>)
8. Keep all dependencies up to date: check `pubspec.yaml` in the main app AND each package in `packages/` against <https://pub.dev>
9. After editing any `.md` file, run `npx markdownlint-cli <file>` and fix all errors before considering the edit complete
