# Testing Guide

How to run, configure, and write tests for the Soliplex Flutter project.

## Running Tests

### With randomized ordering (recommended)

Randomized ordering catches hidden state dependencies between tests.
The seed is printed at the start of each run so failures are reproducible.

```bash
# Flutter app (root)
flutter test --test-randomize-ordering-seed=random

# Pure Dart packages
cd packages/soliplex_client && dart test --test-randomize-ordering-seed=random
cd packages/soliplex_logging && dart test --test-randomize-ordering-seed=random

# Flutter packages
cd packages/soliplex_client_native && flutter test --test-randomize-ordering-seed=random
```

### Reproducing a failure

When a randomized run fails, the output includes the seed:

```text
Shuffling test order with --test-randomize-ordering-seed=2910225495
```

Re-run with that exact seed to reproduce:

```bash
dart test --test-randomize-ordering-seed=2910225495
```

## Configuration

Each package has a `dart_test.yaml` that configures the test runner.

| Package | Concurrency | Randomization | Tags |
|---------|-------------|---------------|------|
| Root app | default | enabled | - |
| `soliplex_client` | 4 | enabled | - |
| `soliplex_client_native` | default | enabled | - |
| `soliplex_logging` | 4 | enabled | `singleton` |

## Singleton Tests

**Problem:** `LogManager` uses a static singleton (`LogManager.instance`). Tests
that mutate global singletons can leak state into other tests, causing
order-dependent failures that only surface under randomized execution.

**Solution:** Singleton test files are tagged with `@Tags(['singleton'])` and the
`dart_test.yaml` in `soliplex_logging` disables randomization for that tag:

```yaml
# packages/soliplex_logging/dart_test.yaml
tags:
  singleton:
    allow_test_randomization: false
```

The test file declares the tag via a library-level annotation:

```dart
@Tags(['singleton'])
library;

import 'package:test/test.dart';
```

### Writing new singleton tests

If you add tests for another singleton, follow the same pattern:

1. Add `@Tags(['singleton'])` as a library-level annotation in the test file
2. Ensure `setUp` / `tearDown` call `reset()` or equivalent to restore clean state
3. Declare the tag in the package's `dart_test.yaml` if it does not already exist

### Why this matters

Without the tag, randomized ordering could interleave singleton tests with other
tests that also use the logger. A test that runs after a failed singleton test
would inherit dirty global state, producing a flaky failure that is difficult to
diagnose.

## Test Helpers

Test utilities live in `test/helpers/test_helpers.dart`:

- **`TestData`** — factory methods for domain models (centralized so constructor
  changes only need one update)
- **`MockSoliplexApi`** — mocktail mock for API calls
- **`createTestApp`** — wraps widgets with `ProviderScope` and theme for widget
  tests
- **`pumpWithProviders`** — pumps a widget with required Riverpod overrides

## Writing Tests

### Riverpod provider tests

Create a fresh `ProviderContainer` per test and dispose it with `addTearDown`:

```dart
test('loads threads', () async {
  final container = ProviderContainer(overrides: [
    soliplexApiProvider.overrideWithValue(mockApi),
  ]);
  addTearDown(container.dispose);

  // test logic
});
```

### Widget tests

Use `createTestApp` to get proper theme and provider wiring:

```dart
testWidgets('renders message', (tester) async {
  await tester.pumpWidget(
    createTestApp(
      overrides: [/* provider overrides */],
      child: const ChatMessageWidget(message: msg),
    ),
  );

  expect(find.text('hello'), findsOneWidget);
});
```
