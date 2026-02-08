# ADR-001: White-Label Architecture for Soliplex Frontend

**Status:** Accepted

**Date:** 2025-01-21

**Branch:** `feat/appshell-extraction`

## Context

The Soliplex Flutter app was a monolithic application with hardcoded branding,
backend URL, and feature configuration. External teams needed to create
white-label versions with their own branding and backend, but this required
forking the entire codebase.

We needed to make the app reusable as a library while:

- Minimizing API surface area for maintainability
- Avoiding breaking changes that would disrupt consumers
- Supporting future extensibility without over-engineering now

## Decisions

### 1. Configuration-Based Whitelabeling (v1 Scope)

**Decision:** Implement v1 (configuration-driven) whitelabeling only.
Defer v2 (composition-based framework with custom routes, screen replacement,
provider injection) until customer demand requires it.

**Rationale:** YAGNI. Configuration covers ~80% of typical whitelabel needs:
app name, colors, feature flags, backend URL, route visibility. Building
extension points before knowing real requirements leads to wrong abstractions.

**What consumers CAN customize (v1):**

- App name and branding
- Theme colors (15 semantic tokens)
- Feature flags (HTTP inspector, quizzes, settings, version info)
- Default backend URL
- Route visibility (home, rooms)
- Initial route

**What consumers CANNOT customize (deferred to v2):**

- Add custom routes
- Replace core screens
- Inject custom providers
- Own the `runApp()` entry point

### 2. Single Entry Point Function

**Decision:** Expose `runSoliplexApp({SoliplexConfig config})` as the only
entry point. The function calls `runApp()` internally.

**Rationale:**

- Simplest possible API for consumers
- Encapsulates initialization complexity (OAuth capture, auth storage, package
  info loading)
- Prevents consumers from misconfiguring the `ProviderScope`

**Trade-off:** Consumers cannot wrap the app with their own providers. This is
acceptable for v1; if needed, v2 can return a `Widget` instead.

### 3. No Global State

**Decision:** All configuration flows through Riverpod providers via
`ProviderScope.overrides`. No static variables, singletons, or global config.

**Rationale:**

- Testability: Tests can override any configuration
- Predictability: No hidden state that varies between runs
- Hot reload: Config changes apply immediately

**Implementation:**

```dart
runApp(
  ProviderScope(
    overrides: [
      shellConfigProvider.overrideWithValue(config),
      // ... other injected values
    ],
    child: const SoliplexApp(),
  ),
);
```

### 4. Minimal Public API Surface

**Decision:** Export only what external consumers need via
`lib/soliplex_frontend.dart`. Internal implementation details remain private.

**Exports:**

- `runSoliplexApp` - Entry point
- `SoliplexConfig`, `Features`, `RouteConfig`, `ThemeConfig` - Configuration
- `SoliplexColors`, `lightSoliplexColors`, `darkSoliplexColors` - Theming

**Rationale:** Smaller API surface = fewer breaking changes = happier consumers.
Internal refactoring doesn't affect external code.

### 5. API Contract Tests

**Decision:** Add compilation-based contract tests that verify every public
export can be instantiated with expected parameters. Tests fail to compile if
signatures change.

**Rationale:** Breaking changes to public API must be intentional and versioned.
Contract tests catch accidental breaks before they reach consumers.

**Convention:** Contract test files include a prominent header:

```dart
// !! MAJOR VERSION BUMP REQUIRED !!
//
// If these tests fail or need modification due to codebase changes, it means
// the public API has changed in a breaking way. You MUST:
//
//   1. Increment the MAJOR version in pubspec.yaml
//   2. Use a conventional commit with "BREAKING CHANGE:" in the footer
//   3. Update these tests to reflect the new API
```

## Consequences

### Positive

- External teams can create white-label apps with a single function call
- Public API is small and stable
- Breaking changes are caught by contract tests before release
- No global state simplifies testing and debugging
- Clear upgrade path to v2 if needed

### Negative

- Consumers wanting deep customization must wait for v2
- `runSoliplexApp()` controlling `runApp()` limits some advanced use cases
- Contract tests add maintenance overhead when API intentionally changes

### Neutral

- Three-package structure remains: `soliplex_frontend`, `soliplex_client`,
  `soliplex_client_native`
- Each package has its own contract tests and versioning

## Future Considerations (v2)

If customer demand requires it, v2 migration involves:

1. **Invert control:** Return `Widget` instead of calling `runApp()`
2. **Open the router:** Add `additionalRoutes` to `SoliplexConfig`
3. **Widget builders:** Add `ScreenBuilders` for replacing Login, Home, etc.
4. **Provider injection:** Define interfaces consumers can override

These changes would be breaking and require a major version bump.

## Implementation Reference

See [APPSHELL_EXTRACTION.md](../APPSHELL_EXTRACTION.md) for:

- Architecture diagrams
- File organization details
- Testing and verification procedures
- Local development setup
