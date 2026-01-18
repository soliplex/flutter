# Provider Testing Patterns

This document explains the required patterns for testing widgets and providers in the
Soliplex Flutter application after the `shellConfigProvider` changes.

## Background

As of the appshell-extraction work, `shellConfigProvider` throws `UnimplementedError` when
accessed without being overridden:

```dart
final shellConfigProvider = Provider<SoliplexConfig>((ref) {
  throw UnimplementedError(
    'shellConfigProvider must be overridden in ProviderScope. '
    'Use runSoliplexApp() or manually override in ProviderScope.',
  );
});
```

This prevents accidental use of global mutable state and ensures white-label apps
explicitly configure their shell settings.

## Test Helper Functions

The following helper functions automatically include the `shellConfigProvider` override:

### `createTestApp()` (test/helpers/test_helpers.dart)

```dart
Widget createTestApp({
  required Widget home,
  List<dynamic> overrides = const [],
  void Function(ProviderContainer)? onContainerCreated,
});
```

Automatically includes:

- `packageInfoProvider.overrideWithValue(testPackageInfo)`
- `shellConfigProvider.overrideWithValue(const SoliplexConfig())`

**Use this for most widget tests.**

### `createMockedAuthDependencies()` (test/helpers/test_helpers.dart)

Returns a record with auth mock overrides that also includes `shellConfigProvider`.

**Use this when testing auth-related functionality.**

## When You Need Manual Overrides

If you create your own `ProviderContainer` directly (not via helper functions), you
**must** add the `shellConfigProvider` override:

```dart
// WRONG - will throw UnimplementedError
final container = ProviderContainer(
  overrides: [
    authProvider.overrideWith(() => MyMockAuth()),
  ],
);

// CORRECT
final container = ProviderContainer(
  overrides: [
    shellConfigProvider.overrideWithValue(const SoliplexConfig()),
    authProvider.overrideWith(() => MyMockAuth()),
  ],
);
```

### Common Scenarios Requiring Manual Overrides

1. **Auth state transition tests** - When you need to manipulate auth state during
   the test via a controllable notifier
2. **Router tests** - When testing navigation with custom GoRouter configurations
3. **Integration tests** - When testing complex provider interactions
4. **Tests needing container access** - When you call `container.read()` during the test

### Example: Auth State Transition Test

```dart
testWidgets('session expiry redirects to /login', (tester) async {
  final container = ProviderContainer(
    overrides: [
      // REQUIRED: Always include shellConfigProvider
      shellConfigProvider.overrideWithValue(const SoliplexConfig()),
      // Test-specific overrides
      authProvider.overrideWith(() => _ControllableAuthNotifier(...)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(...),
    ),
  );

  // Now you can manipulate auth state
  (container.read(authProvider.notifier) as _ControllableAuthNotifier)
      .setUnauthenticated();
  await tester.pumpAndSettle();
});
```

## Required Imports

When adding `shellConfigProvider` overrides manually, add these imports:

```dart
import 'package:soliplex_frontend/core/models/soliplex_config.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
```

## Troubleshooting

### Error: `UnimplementedError: shellConfigProvider must be overridden`

This error means a widget or provider tried to read `shellConfigProvider` without it
being overridden. Solutions:

1. **If using a helper function**: Ensure you're using `createTestApp()` or
   `createMockedAuthDependencies()`, which include the override automatically
2. **If creating ProviderContainer directly**: Add `shellConfigProvider.overrideWithValue(
   const SoliplexConfig())` to your overrides list
3. **If using ProviderScope directly**: Add the override:

```dart
ProviderScope(
  overrides: [
    shellConfigProvider.overrideWithValue(const SoliplexConfig()),
    // other overrides...
  ],
  child: MaterialApp(...),
)
```

### Error: `ProviderException` wrapping `UnimplementedError`

Riverpod 3.0 wraps provider errors in `ProviderException`. If you're testing that the
provider throws when not overridden, check for the error message:

```dart
expect(
  () => container.read(shellConfigProvider),
  throwsA(
    predicate((e) => e.toString().contains('shellConfigProvider must be overridden')),
  ),
);
```

## File Locations Updated

The following test files were updated to use the correct patterns:

- `test/helpers/test_helpers.dart` - Added `shellConfigProvider` to `createTestApp()`
  and `createMockedAuthDependencies()`
- `test/core/router/app_router_test.dart` - Added override to `createRouterAppAt()`
  and direct `ProviderContainer` usages
- `test/features/home/home_screen_test.dart` - Added override to `_createAppWithRouter()`
- `test/features/login/login_screen_test.dart` - Added override to `_createAppWithRouter()`
  and direct `ProviderContainer` usage
- `test/features/quiz/quiz_screen_test.dart` - Added override to `buildQuizScreen()`
- `test/features/room/room_screen_test.dart` - Added override to direct
  `ProviderContainer` usage
- `test/shared/widgets/app_shell_test.dart` - Added override to all `ProviderScope` usages
- `test/core/providers/shell_config_provider_test.dart` - Updated test for Riverpod 3.0
  exception wrapping
