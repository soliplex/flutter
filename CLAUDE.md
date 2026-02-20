# Soliplex Frontend

Cross-platform Flutter frontend for Soliplex AI-powered RAG system.

## Quick Reference

```bash
flutter pub get                           # Install dependencies
flutter run -d chrome --web-port 59001    # Run (web)
flutter test                              # Run tests
flutter test --coverage                   # Run tests with coverage
dart format .                             # Format code
flutter analyze --fatal-infos             # Analyze (must be 0 issues)
npx markdownlint-cli "<file>"            # Lint markdown after editing .md files
```

## Project Structure

```text
lib/
  core/           # auth/, logging/, models/, providers/ (17), router/
  design/         # Color, theme, tokens (design system)
  features/       # auth, chat, history, home, inspector, log_viewer,
                  # login, quiz, room, rooms, settings
  shared/         # Reusable widgets and utilities
packages/
  soliplex_client/        # Pure Dart: REST API, AG-UI, domain models
  soliplex_client_native/ # Platform HTTP adapters (Cupertino)
  soliplex_logging/       # Pure Dart: logging, DiskQueue, BackendLogSink
docs/                     # Documentation (see docs/index.md)
```

## Architecture

Three layers: UI (features/) -> Core (providers, auth, logging) -> soliplex_client (pure Dart).
State management: Riverpod (manual providers, no codegen).
Navigation: GoRouter. Logging: soliplex_logging via `Loggers.*` accessors.

### Clean Architecture (Dependency Rule)

Source code dependencies point inward only. See `PLANS/0006-clean-architecture/`
for the full target architecture and rationale.

**Domain** (`soliplex_client` + `lib/core/domain/`): Rich objects that own
their behavior — state machines, composition rules, validation, invariants.
Pure Dart. No Flutter, no Riverpod, no I/O. `lib/core/models/` contains
legacy types (config, run state) that predate `domain/`. Domain types in
`models/` migrate to `domain/` during reworks; new domain types go directly
in `lib/core/domain/`.

**Use Cases** (`lib/core/usecases/`): Plain Dart classes that orchestrate
domain objects and I/O. Named by user intent: `SubmitQuizAnswer`,
`ResumeThreadWithMessage`, `SelectAndPersistThread`. Use cases do NOT
contain business rules — they call domain methods and handle side effects.

**Providers** (`lib/core/providers/`): Thin glue for dependency injection
and reactive rebuilds. Nothing more. Rules:

- Provider files contain only provider declarations and thin Notifiers that
  delegate to domain objects and use cases. If a provider file defines sealed
  classes, encodes business rules, or manages state transitions, extract that
  logic to `lib/core/domain/` or `lib/core/usecases/`.
- Do NOT put sealed classes in provider files — they belong in `lib/core/domain/`.
- Do NOT put state machines in Notifiers — add methods to domain objects.
  Notifiers are Humble Objects: push all testable logic out, leave only
  trivial delegation.
- If a Notifier makes API calls or performs any I/O, extract a use case in
  `lib/core/usecases/`. The dependency rule has no size threshold — "it's
  just one API call" is not a reason to skip extraction.
- Do NOT create convenience providers wrapping `.select()` — use `.select()` at call sites.
- When adding a feature that needs state, create or extend a domain class first,
  then expose it via a provider.

## Development Rules

- Use `equatable` for value equality — extend `Equatable` and declare
  `props`. Only include fields that define identity in `props`; exclude
  derived getters and diagnostic fields (e.g. `stackTrace`)
- KISS, YAGNI, SOLID - simple solutions over clever ones
- Edit existing files; do not create new ones without need
- Match surrounding code style exactly
- Always refer to and abide by `docs/rules/flutter_rules.md`
- Never use `// ignore:` directives - restructure code instead
- Keep `soliplex_client` and `soliplex_logging` pure Dart (no Flutter imports)
- Platform-specific code goes in `soliplex_client_native`

## Code Quality

After any code modification, run in order:

1. `dart format .` (must produce no changes)
2. `flutter analyze --fatal-infos` (must be 0 errors, warnings, and hints)
3. `flutter test` (must pass; targeted tests during dev, full suite before commit)
4. Coverage target: 85%+

## Testing

- Mirror lib/ structure in test/
- Unit tests for models and providers; widget tests for UI components
- Helpers in test/helpers/test_helpers.dart: `MockSoliplexApi`, `TestData`, `pumpWithProviders()`
- Use `mocktail` for mocking (not mockito)

## Documentation

- [docs/index.md](docs/index.md) - Documentation index
- [docs/rules/flutter_rules.md](docs/rules/flutter_rules.md) - Development conventions
- [docs/guides/developer-setup.md](docs/guides/developer-setup.md) - Environment setup
- [docs/logging-quickstart.md](docs/logging-quickstart.md) - Logging usage guide
- [docs/guides/logging.md](docs/guides/logging.md) - Logging architecture
- [docs/summary/client.md](docs/summary/client.md) - soliplex_client package
