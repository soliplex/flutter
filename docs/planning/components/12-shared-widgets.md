# 12 - Shared Widgets

## Overview

Reusable UI building blocks ensuring consistency in layout, error handling, loading
states, and navigation scaffolding. Provides the application shell pattern and
standardized async state handling.

## Files

| File | Purpose |
|------|---------|
| `lib/shared/widgets/app_shell.dart` | Top-level screen wrapper |
| `lib/shared/widgets/async_value_handler.dart` | Riverpod AsyncValue handler |
| `lib/shared/widgets/empty_state.dart` | Empty list placeholder |
| `lib/shared/widgets/error_display.dart` | Standardized error view |
| `lib/shared/widgets/loading_indicator.dart` | Centered loading spinner |
| `lib/shared/widgets/platform_adaptive_progress_indicator.dart` | Platform spinner |
| `lib/shared/widgets/shell_config.dart` | Shell configuration object |

## Public API

### Shell & Navigation

**`AppShell`** (`ConsumerWidget`) - Top-level screen wrapper

- Provides single Scaffold managing drawers (nav, HTTP inspector)
- Responsive drawer width based on breakpoints
- Conditionally shows HttpInspectorPanel via feature flags
- Allows custom end drawer override

**`ShellConfig`** - Configuration data class

- title, actions, leading widget, navigation drawer

### State Handling

**`AsyncValueHandler<T>`** - Generic Riverpod AsyncValue widget

- Standardizes data/loading/error UI states
- Routes errors to ErrorDisplay, loading to LoadingIndicator

### UI Components

**`ErrorDisplay`** - Standardized error view

- Maps exceptions to user-friendly messages and icons
- "Show details" expandable for technical debugging
- Copy-to-clipboard for debug details

**`LoadingIndicator`** - Centered spinner with optional text

**`EmptyState`** - Placeholder for empty lists (icon + message)

**`PlatformAdaptiveProgressIndicator`** - Platform-specific spinner

- CupertinoActivityIndicator on iOS/macOS
- CircularProgressIndicator elsewhere

## Dependencies

### External Packages

- `flutter` - UI framework
- `flutter_riverpod` - State management
- `soliplex_client` - Exception types

### Internal Dependencies

| Domain | Imports |
|--------|---------|
| Core/Providers | `shell_config_provider`, `thread_history_cache` |
| Design | Theme extensions, breakpoints, spacing |
| Features | `HttpInspectorPanel` (inspector feature) |
| Shared | `platform_resolver` |

## Data Flow

### Shell Initialization

```text
1. Screens wrap content in AppShell with ShellConfig
2. AppShell reads featuresProvider for HTTP Inspector flag
3. Constructs Scaffold with configured AppBar
4. Mounts HttpInspectorPanel or customEndDrawer
```

### Async State Flow

```text
1. Features use AsyncValueHandler with Riverpod AsyncValue
2. Loading → LoadingIndicator → PlatformAdaptiveProgressIndicator
3. Error → ErrorDisplay:
   ├─ Unwraps exception (checks wrapper types)
   └─ Determines UI message/icon by exception type
4. Data → Executes provided data builder callback
```

## Architectural Patterns

### Shell Pattern

`AppShell` manages global UI concerns (drawers, inspector) so screens focus on content.

### Wrapper/Decorator

`AsyncValueHandler` decorates Riverpod's `.when()` for UI consistency.

### Configuration Object

`ShellConfig` is Parameter Object pattern decoupling UI configuration from rendering.

### Platform Adaptation

Strategy pattern via `PlatformAdaptiveProgressIndicator` and `platform_resolver`.

### Exception Mapping

`ErrorDisplay` centralizes error interpretation, converting domain exceptions to UI states.

## Cross-Component Dependencies

### Depends On

- **05 - Threads**: Accessing thread_history_cache for error display logic
- **09 - Inspector**: Integrating inspector panel views in App Shell
- **10 - Configuration**: Accessing shell configuration
- **11 - Design System**: Base styling and tokens
- **14 - HTTP Layer**: Exception types for error display
- **17 - Utilities**: Platform resolver and formatting functions

### Used By

- **02 - Authentication**: Login and auth UI elements
- **05 - Threads**: History list and item widgets
- **06 - Rooms**: Room display widgets
- **08 - Chat UI**: Chat interface elements
- **09 - Inspector**: Inspector UI elements
- **19 - Router**: Route wrapper widgets
- **20 - Quiz**: Quiz feature UI elements

## Contribution Guidelines

### DO

- **Use `AsyncValueHandler` for all data fetching UI:** Wrap Riverpod `AsyncValue` results with this widget to ensure consistent loading states, error handling, and retry logic across the app.
- **Wrap top-level screens in `AppShell`:** Always use `AppShell` to manage the global `Scaffold`, `AppBar`, and HTTP Inspector drawer access.
- **Map specific exceptions in `ErrorDisplay`:** When adding new domain exceptions, update `ErrorDisplay._getErrorMessage` to provide user-friendly text instead of raw error strings.
- **Use `ShellConfig` for UI configuration:** Pass view-specific configuration (titles, actions, floating action buttons) through the `ShellConfig` object rather than creating custom Scaffolds.
- **Prioritize Accessibility:** Wrap interactive or visual-only elements in `Semantics` widgets following the established patterns.

### DON'T

- **Don't nest Scaffolds:** Never place a `Scaffold` inside the `body` of an `AppShell`. This breaks the context required to open the global drawers.
- **Don't implement ad-hoc error parsing:** Avoid `if (e is MyError)` logic inside individual feature widgets. Move exception mapping logic to `ErrorDisplay`.
- **No business logic in `AppShell`:** The shell should only handle layout and display. Logic for determining *what* to show should come from providers.
- **No hardcoded loading spinners:** Do not use raw `CircularProgressIndicator` in feature widgets. Use `LoadingIndicator` or `PlatformAdaptiveProgressIndicator`.
- **Don't bypass the decorator chain:** Do not bypass `AsyncValueHandler` to implement custom `when(data, error, loading)` blocks unless the UI requirement is drastically different.

### Extending This Component

- **Adding Global Drawers:** Modify `AppShell` to accept new drawer widgets if they need to be accessible globally.
- **New Exception Types:** Update `_unwrapError` and `_getErrorMessage` in `ErrorDisplay` when introducing new exception wrappers or domain error types.
- **Shell Configuration:** Extend `ShellConfig` if new `AppBar` features are required by multiple screens.
