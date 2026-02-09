# Flutter Development Rules

Expert Flutter/Dart development guide emphasizing performance, maintainability, and modern best practices.

## Core Principles

- **SOLID** - Apply throughout the codebase
- **Composition over inheritance** - Build complex widgets from smaller ones
- **Immutability** - Prefer immutable data structures; widgets should be immutable
- **Separation of concerns** - UI logic separate from business logic

## Code Style

```text
PascalCase  → classes
camelCase   → members, variables, functions, enums
snake_case  → file names
```

- Line length: 80 characters max
- Functions: single purpose, <20 lines
- Names: meaningful, descriptive, no abbreviations
- Comments: explain *why*, not *what*
- No trailing comments

## Dart Best Practices

**Null Safety:**

- Write soundly null-safe code
- Avoid `!` unless value is guaranteed non-null
- Use pattern matching to simplify null handling

**Async:**

- Use `Future`/`async`/`await` for single async operations
- Use `Stream` for sequences of async events
- Always handle errors in async code

**Modern Features:**

- Use pattern matching where it simplifies code
- Use records for returning multiple values
- Use exhaustive `switch` expressions (no `break` needed)
- Use arrow syntax for one-line functions

**Class Organization:**

- Related classes in same library file
- Group related libraries in same folder
- Document all public APIs with `///` comments

## Flutter Best Practices

**Widgets:**

- `StatelessWidget` must be immutable
- Prefer small, private Widget classes over helper methods returning Widget
- Break large `build()` methods into smaller widget classes
- Use `const` constructors whenever possible

**Performance:**

- Use `ListView.builder` / `SliverList` for long lists (lazy loading)
- Use `compute()` for expensive calculations (separate isolate)
- Never do network calls or heavy computation in `build()`

**State Management (this project uses Riverpod):**

- Separate ephemeral state from app state
- Use manual constructor dependency injection
- Abstract data sources with repositories for testability

**Navigation:**

- Use `go_router` for declarative routing and deep linking
- Use `Navigator` only for dialogs/temporary views

## Architecture

**Layers:**

```text
Presentation  → widgets, screens
Domain        → business logic
Data          → models, API clients
Core          → shared utilities, extensions
```

**Feature-based Organization:**

Each feature has its own directory under `lib/features/` with optional `widgets/`
and `models/` subfolders as needed.

## Testing

**Patterns:**

- Arrange-Act-Assert (Given-When-Then)
- Prefer fakes/stubs over mocks
- Use `mocktail` when mocking is necessary

**Types:**

- Unit tests (`package:test`) - domain logic, data layer, state
- Widget tests (`package:flutter_test`) - UI components
- Integration tests (`package:integration_test`) - end-to-end flows

**Assertions:**

Use standard `expect()` matchers from `package:test` and `package:flutter_test`.

## Theming

**Material 3:**

- Use `ColorScheme.fromSeed()` for harmonious palettes
- Provide both `theme` and `darkTheme` to MaterialApp
- Centralize component styles in `ThemeData`

**Custom Tokens:**

Use `ThemeExtension<T>` for styles not in standard ThemeData.

**Accessibility:**

- Text contrast ratio: 4.5:1 minimum (3:1 for large text)
- Test with increased system font size
- Use `Semantics` widget for screen reader labels

## Layout

**Overflow Prevention:**

- `Expanded` - fill remaining space
- `Flexible` - shrink to fit (don't mix with Expanded)
- `Wrap` - move to next line when overflowing
- `SingleChildScrollView` - fixed content larger than viewport
- `ListView.builder` - long lists

**Responsiveness:**

Use `LayoutBuilder` or `MediaQuery` for responsive layouts.

## Logging

Use the `Loggers` class from `soliplex_logging` instead of `print` or
`dart:developer`:

```dart
import 'package:soliplex_frontend/core/logging/loggers.dart';

Loggers.auth.info('User logged in');
Loggers.http.debug('GET /api/users');
Loggers.activeRun.error('Failed', error: e, stackTrace: s);
```

See [Logging Quickstart](../logging-quickstart.md) for the full list of
available loggers and log level guidelines.

## Quick Reference

| Do | Don't |
|----|-------|
| `const` constructors | Mutable widgets |
| Small, focused, reusable Widget classes | Giant `build()` methods |
| Pattern matching | Excessive null checks with `!` |
| `ListView.builder` | `ListView` with large lists |
| Fakes/stubs in tests | Heavy mock usage with mockito |
| `Theme.of(context)` | Hardcoded colors/styles |
