# AGENTS.md

Instructions for AI coding agents working on the Soliplex Flutter frontend.

## Project Overview

Cross-platform Flutter frontend (iOS, macOS, Android, Web) for Soliplex, an
AI-powered RAG system. The app provides chat with streaming AI responses via
the AG-UI protocol, multi-room support, OIDC authentication, and white-label
configuration.

## Setup

```bash
flutter pub get
```

For iOS/macOS, install CocoaPods dependencies:

```bash
cd ios && pod install && cd ..
cd macos && pod install && cd ..
```

Platform-specific code signing setup is required for iOS/macOS. See
`docs/guides/developer-setup.md` for details.

## Build and Test Commands

```bash
# Format (must produce no changes)
dart format .

# Analyze (must report 0 issues)
flutter analyze --fatal-infos

# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run a specific test file
flutter test test/core/providers/rooms_provider_test.dart

# Run package tests
cd packages/soliplex_logging && dart test && cd ../..
cd packages/soliplex_client && dart test && cd ../..

# Build web release
flutter build web --release

# Lint markdown
npx markdownlint-cli "<file>"
```

All three checks (format, analyze, test) must pass before any change is
considered complete. Coverage target is 85%+. The CI pipeline enforces a
minimum of 78%. CI also runs tests for each package independently with
randomized ordering.

## Architecture

Three-layer architecture:

- **UI** (`lib/features/`) - Feature screens and widgets
- **Core** (`lib/core/`) - Riverpod providers, auth, logging, navigation
- **Client** (`packages/soliplex_client/`) - Pure Dart REST/AG-UI client

Three packages under `packages/`:

- `soliplex_client` - Pure Dart (no Flutter). REST API, AG-UI streaming,
  domain models, HTTP transport. Must never import Flutter.
- `soliplex_client_native` - Flutter package providing platform HTTP adapters
  (CupertinoHttpClient for iOS/macOS).
- `soliplex_logging` - Pure Dart (no Flutter). LogManager, sinks (Console,
  Memory, DiskQueue, BackendLogSink). Must never import Flutter.

State management uses Riverpod with manual providers (no codegen). Navigation
uses GoRouter. Logging uses `soliplex_logging` via type-safe `Loggers.*`
static accessors.

## Code Style

- Follow `docs/rules/flutter_rules.md` for all conventions
- PascalCase for classes, camelCase for members, snake_case for file names
- Line length: 80 characters max
- Use `const` constructors wherever possible
- Prefer small widget classes over helper methods returning Widget
- Use `mocktail` for test mocking (not mockito)
- Use `Loggers.*` for logging (never `print` or `dart:developer`)
- Never use `// ignore:` directives; restructure code instead
- Linting: `very_good_analysis` (strict)

## Testing

- Test directory mirrors `lib/` structure
- Unit tests for models, providers, and pure Dart logic
- Widget tests for UI components
- Test helpers in `test/helpers/test_helpers.dart`:
  - `MockSoliplexApi` - API mock for widget tests
  - `TestData` - Factory for test fixtures
  - `pumpWithProviders()` - Wraps widgets with required providers

## Project Structure

```text
lib/
  core/
    auth/         # OIDC authentication (platform-specific flows)
    logging/      # Loggers class, LogConfig, provider lifecycle
    models/       # AppConfig, Features, ThemeConfig, SoliplexConfig
    providers/    # 17 Riverpod providers (state management)
    router/       # GoRouter configuration
  design/         # Color scheme, theme, design tokens (breakpoints, radii)
  features/       # 11 feature modules:
                  #   auth, chat, history, home, inspector, log_viewer,
                  #   login, quiz, room, rooms, settings
  shared/         # Reusable widgets and utilities
packages/
  soliplex_client/        # Pure Dart REST/AG-UI client
  soliplex_client_native/ # Platform HTTP adapters
  soliplex_logging/       # Pure Dart logging package
test/                     # Mirrors lib/ structure
docs/                     # Project documentation
```

## Security

- Never commit secrets, tokens, or credentials
- Pre-commit hooks run `gitleaks` for secret detection
- OIDC tokens stored via `flutter_secure_storage` (Keychain on Apple platforms)
- Backend log shipping uses JWT auth; no client-side credential exposure
- Code signing configs (`Local.xcconfig`) are gitignored

## PR Guidelines

- Branch from `main`; PRs target `main`
- CI must pass: lint (format, analyze, markdown), test (all packages), coverage >= 78%
- Keep `soliplex_client` and `soliplex_logging` as pure Dart packages
- Run `npx markdownlint-cli` on any modified markdown files

## Key Documentation

- `docs/index.md` - Documentation index and project overview
- `docs/rules/flutter_rules.md` - Development conventions and best practices
- `docs/guides/developer-setup.md` - Platform setup (iOS, macOS, web)
- `docs/logging-quickstart.md` - How to use the logging system
- `docs/guides/logging.md` - Logging architecture (DiskQueue, BackendLogSink)
- `docs/summary/client.md` - soliplex_client package architecture
- `docs/adr/` - Architecture Decision Records
