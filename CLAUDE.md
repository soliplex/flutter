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
  core/           # auth/, domain/, logging/, models/, providers/, router/, usecases/
  design/         # Color, theme, tokens (design system)
  features/       # auth, chat, history, home, inspector, log_viewer,
                  # login, quiz, room, rooms, settings
  shared/         # Reusable widgets and utilities
packages/
  soliplex_client/        # Pure Dart: REST API client, AG-UI protocol, DTOs
  soliplex_client_native/ # Platform HTTP adapters (Cupertino)
  soliplex_logging/       # Pure Dart: logging, DiskQueue, BackendLogSink
docs/                     # Documentation (see docs/index.md)
```

## Architecture

Source code dependencies point inward only (the dependency rule). Four
layers, from innermost to outermost:

**Domain** (`lib/core/domain/`): The richest layer. Domain objects own
the business rules of the system — state machines (states and the
transitions between them), composition rules, validation, and invariants.
They are pure Dart: no Flutter, no Riverpod, no I/O. When domain logic
needs I/O, the domain object defines the decision; the use case executes
the side effect. `lib/core/models/` and `packages/soliplex_client/lib/src/domain/`
contain legacy types that predate `lib/core/domain/`; they migrate inward
during reworks.

**Use Cases** (`lib/core/usecases/`): Plain Dart classes that orchestrate
domain objects and I/O. Named by user intent: `SubmitQuizAnswer`,
`ResumeThreadWithMessage`, `SelectAndPersistThread`. Use cases do NOT
contain business rules — they call domain methods and handle side effects
(API calls, persistence). Every user action involving I/O gets a use case,
regardless of how simple it appears — no size threshold.

**Providers** (`lib/core/providers/`): Riverpod providers are interface
adapters — thin glue for dependency injection and reactive rebuilds.
Nothing more. Providers do NOT manage state — domain objects do. Riverpod
is the wiring framework, not the state management framework. Rules:

- Provider files contain only provider declarations and thin Notifiers that
  delegate to domain objects and use cases (the Humble Object pattern).
- Do NOT put sealed classes, state machines, or business logic in provider
  files — extract to `lib/core/domain/` or `lib/core/usecases/`.
- If a Notifier performs any I/O, extract a use case. No size threshold.
- Do NOT create convenience providers wrapping `.select()`.
- When adding a feature, create or extend a domain class first, then
  expose via a provider.

**UI** (`lib/features/`): Widgets are humble. They render objects built
by inner layers, consume streams, and dispatch user intent to providers.
UI files contain only UI logic: layout, animation, text rendering,
visibility, navigation. Business decisions belong in domain objects, not
in widget `build()` methods or callbacks.

`soliplex_client` is an interface adapter — a pure Dart HTTP client that
translates between domain types and the backend REST/AG-UI APIs. It defines
DTOs shaped by the backend contract; domain types shaped by business rules
live in `lib/core/domain/`. Do not create new domain types in
`soliplex_client`.

Navigation: GoRouter. Logging: soliplex_logging via `Loggers.*` accessors.
Riverpod uses manual providers (no codegen).

When touching existing code, actively improve cohesion and reduce coupling.
Prefer enriching an existing domain object over creating a new small class.
The goal is fewer, richer objects — not many thin ones. See
`PLANS/0006-clean-architecture/` for rationale and examples. For the
original principles:
<https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html>

## Development Rules

- KISS, YAGNI, SOLID — simple solutions over clever ones
- Actively improve cohesion and reduce coupling when touching existing code
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
- **Domain tests**: Plain Dart unit tests for domain objects — state
  transitions, business rules, validation. No mocks needed for pure logic.
- **Use case tests**: Unit tests with mocked I/O ports (API, persistence).
  Verify orchestration: correct calls in the right order.
- **Provider tests**: Verify wiring only — that providers construct the
  right objects and that `ref.watch()` triggers rebuilds.
- **Widget tests**: For UI components using `pumpWithProviders()`
- Helpers in test/helpers/test_helpers.dart: `MockSoliplexApi`, `TestData`,
  `pumpWithProviders()`
- Use `mocktail` for mocking (not mockito)

## Documentation

- [docs/index.md](docs/index.md) - Documentation index
- [docs/rules/flutter_rules.md](docs/rules/flutter_rules.md) - Development conventions
- [docs/guides/developer-setup.md](docs/guides/developer-setup.md) - Environment setup
- [docs/logging-quickstart.md](docs/logging-quickstart.md) - Logging usage guide
- [docs/guides/logging.md](docs/guides/logging.md) - Logging architecture
- [docs/summary/client.md](docs/summary/client.md) - soliplex_client package
