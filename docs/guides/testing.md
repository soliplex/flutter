# Testing Guide

## Running Tests

Use `--test-randomize-ordering-seed=random` to catch hidden state dependencies.
The seed is printed at the start of each run for reproducibility.

```bash
# Flutter app (root)
flutter test --test-randomize-ordering-seed=random

# Pure Dart packages
cd packages/soliplex_client && dart test --test-randomize-ordering-seed=random
cd packages/soliplex_logging && dart test --test-randomize-ordering-seed=random
```

To reproduce a specific failure, re-run with the seed from the output:

```bash
dart test --test-randomize-ordering-seed=2910225495
```

## Configuration

Each package has a `dart_test.yaml` configuring the test runner.

| Package | Concurrency | Tags |
|---------|-------------|------|
| Root app | default | — |
| `soliplex_client` | 4 | — |
| `soliplex_client_native` | default | — |
| `soliplex_logging` | 4 | `singleton` |

All packages have `allow_test_randomization: true`.

## Singleton Tests

`LogManager` is a static singleton. Tests that mutate it can leak state,
causing order-dependent failures under randomized execution.

Singleton test files opt out of randomization via a tag:

```dart
// packages/soliplex_logging/test/log_manager_test.dart
@Tags(['singleton'])
library;
```

```yaml
# packages/soliplex_logging/dart_test.yaml
tags:
  singleton:
    allow_test_randomization: false
```

### Adding new singleton tests

1. Add `@Tags(['singleton'])` as a library-level annotation
2. Call `reset()` (or equivalent) in `setUp` / `tearDown`
3. Declare the tag in the package's `dart_test.yaml` if not already present
