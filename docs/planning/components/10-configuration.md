# 10 - Configuration

## Overview

Configuration system supporting white-label applications. Separates immutable
shell configuration (build-time branding, features, routes) from mutable app
configuration (runtime user settings like backend URL).

## Files

| File | Purpose |
|------|---------|
| `lib/core/models/app_config.dart` | Mutable runtime settings |
| `lib/core/models/features.dart` | Feature flags |
| `lib/core/models/logo_config.dart` | Branding assets |
| `lib/core/models/route_config.dart` | Navigation configuration |
| `lib/core/models/soliplex_config.dart` | Root configuration aggregate |
| `lib/core/models/theme_config.dart` | Light/dark theme colors |
| `lib/core/providers/config_provider.dart` | Runtime config provider |
| `lib/core/providers/shell_config_provider.dart` | Static config provider |

## Public API

### Models (Value Objects)

**`SoliplexConfig`** - Root white-label configuration

- Aggregates branding, features, routes, themes, API defaults

**`AppConfig`** - Mutable runtime settings

- Currently holds `baseUrl`

**`Features`** - Feature toggle flags

- `enableHttpInspector`, `enableQuizzes`
- `.minimal()` constructor for opt-in configuration

**`LogoConfig`** - Branding assets

- Supports assets from current app or external packages

**`RouteConfig`** - Navigation visibility

- `showHomeRoute`, `initialRoute`, `authenticatedLandingRoute`

**`ThemeConfig`** - Color configuration

- Wrapper for Light/Dark `SoliplexColors`

### Providers

**`shellConfigProvider`** - Immutable `SoliplexConfig` accessor

- Throws `UnimplementedError` if not overridden (enforces explicit config)

**`featuresProvider`** - Convenience accessor for `Features`

**`configProvider`** (`NotifierProvider<ConfigNotifier, AppConfig>`)

- Manages mutable `AppConfig`
- `setBaseUrl(String)` - Updates and persists to SharedPreferences

### Helper Functions

- `loadSavedBaseUrl()` - Read SharedPreferences before runApp
- `platformDefaultBackendUrl()` - Determine localhost vs origin by platform

## Dependencies

### External Packages

- `flutter_riverpod` - State management
- `shared_preferences` - Settings persistence
- `meta` - Annotations

### Internal Dependencies

| Domain | Imports |
|--------|---------|
| Design | `tokens/colors` |

## Data Flow

### Initialization

```text
1. Build-Time: Consuming app creates const SoliplexConfig
2. Pre-Run: main() calls loadSavedBaseUrl() from SharedPreferences
3. Injection: ProviderScope overrides:
   ├─ shellConfigProvider → SoliplexConfig
   └─ preloadedBaseUrlProvider → saved URL (if any)
```

### URL Resolution (ConfigNotifier)

```text
Priority order:
1. User Preference: preloadedBaseUrlProvider value
2. White-label Default: shellConfigProvider.defaultBackendUrl
3. Platform Fallback: localhost:8000 (native) or Uri.base.origin (web)
```

### Runtime Updates

```text
configProvider.notifier.setBaseUrl(url)
  → Updates in-memory state
  → Writes to SharedPreferences async
```

## Architectural Patterns

### Immutable Configuration

All models use `copyWith` pattern for immutable value objects.

### Forced Dependency Injection

`shellConfigProvider` throws if unimplemented, enforcing explicit app configuration.

### Layered Configuration

- **Shell Configuration**: Static/build-time definitions
- **App Configuration**: Dynamic/runtime user settings

### Platform Abstraction

`platformDefaultBackendUrl` abstracts local dev, native networking, and web origin.

## Cross-Component Dependencies

### Depends On

- **11 - Design System**: Color tokens used within theme configuration models

### Used By

- **01 - App Shell**: App initialization and feature flagging
- **02 - Authentication**: Auth provider configuration (endpoints/scopes)
- **03 - State Core**: API base URLs and backend health checks
- **06 - Rooms**: Configuration specific to room features
- **12 - Shared Widgets**: Configuration injection for shared UI elements
- **19 - Router**: Routing logic dependent on configuration state
- **20 - Quiz**: Quiz feature settings

## Contribution Guidelines

### DO

- **Enforce Immutability:** Always mark configuration classes as `@immutable`. Implement `copyWith`, `operator ==`, and `hashCode` for every new configuration model.
- **Separate Static vs. Runtime:** Place build-time settings (branding, features) in `SoliplexConfig` (accessed via `shellConfigProvider`) and mutable user settings (URL) in `AppConfig` (accessed via `configProvider`).
- **Use Async Pre-loading:** Follow the pattern in `loadSavedBaseUrl()` for runtime settings. Load data in `main()` before `runApp` and inject via `overrideWithValue`.
- **Default to Enabled:** When adding new boolean flags to `Features`, default them to `true` to maintain backward compatibility for existing implementations.
- **Validate Inputs:** Use `assert` statements in constructors (e.g., `RouteConfig`) to prevent invalid configuration states at compile/runtime start.

### DON'T

- **No Mutable State:** Never use non-final fields in configuration objects. State changes must trigger a full object replacement via `copyWith`.
- **No Secrets:** Do not add API keys or secrets to `SoliplexConfig`. This configuration is intended to be committed to source control.
- **No UI Dependencies:** Do not import Flutter UI packages into configuration models. Keep config pure Dart where possible.
- **No Hardcoded Fallbacks in UI:** Do not hardcode default URLs or assets in widgets. Always retrieve them via config providers.
- **Avoid Deep Nesting:** Do not create deeply nested configuration objects. Keep the hierarchy flat under `SoliplexConfig` for easier `copyWith` usage.

### Extending This Component

- **Adding a Feature Flag:** Add the `final bool` to `Features`, update the constructor (default `true`), update `minimal()` (set `false`), and update `copyWith`/`hashCode`.
- **Adding Top-Level Config:** Create a new Value Object (e.g., `SecurityConfig`), add it to `SoliplexConfig`, and ensure it has a default `const` instance.
- **New Runtime Settings:** Add field to `AppConfig`, update `ConfigNotifier` to handle persistence, and update the storage key if needed.
