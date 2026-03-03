# 0011: CI Pipeline Optimization

## Goal

Add all 10 packages to the CI test matrix with dependency-aware path filters,
and separate the web build from the test pipeline.

## Dependency Graph

```text
soliplex_logging           (leaf)
soliplex_schema            (leaf)
soliplex_interpreter_monty (leaf)
soliplex_skills            (leaf)
soliplex_client            → logging
soliplex_client_native     → client (→ logging)
soliplex_agent             → client, logging
soliplex_scripting         → agent, client, interpreter_monty
soliplex_cli               → agent, client, logging
soliplex_tui               → agent, logging
app                        → agent, client, client_native, logging
```

## Path Filters (transitive)

Each filter includes the package itself plus all of its transitive dependencies:

| Target | Triggers on |
|---|---|
| `soliplex_logging` | `packages/soliplex_logging/**` |
| `soliplex_schema` | `packages/soliplex_schema/**` |
| `soliplex_interpreter_monty` | `packages/soliplex_interpreter_monty/**` |
| `soliplex_skills` | `packages/soliplex_skills/**` |
| `soliplex_client` | `packages/soliplex_client/**`, `packages/soliplex_logging/**` |
| `soliplex_client_native` | `packages/soliplex_client_native/**`, `packages/soliplex_client/**`, `packages/soliplex_logging/**` |
| `soliplex_agent` | `packages/soliplex_agent/**`, `packages/soliplex_client/**`, `packages/soliplex_logging/**` |
| `soliplex_scripting` | `packages/soliplex_scripting/**`, `packages/soliplex_agent/**`, `packages/soliplex_client/**`, `packages/soliplex_interpreter_monty/**` |
| `soliplex_cli` | `packages/soliplex_cli/**`, `packages/soliplex_agent/**`, `packages/soliplex_client/**`, `packages/soliplex_logging/**` |
| `soliplex_tui` | `packages/soliplex_tui/**`, `packages/soliplex_agent/**`, `packages/soliplex_logging/**` |
| `app` | `lib/**`, `test/**`, `pubspec.*`, `packages/soliplex_agent/**`, `packages/soliplex_client/**`, `packages/soliplex_client_native/**`, `packages/soliplex_logging/**` |

## Runner Types

| Package | Runner | Reason |
|---|---|---|
| app | `flutter` | Flutter widget tests |
| soliplex_client_native | `flutter` | Platform-specific (Cupertino HTTP) |
| All others | `dart` | Pure Dart packages |

## Workflow Layout (post-change)

| Workflow | File | Triggers | Jobs |
|---|---|---|---|
| Flutter CI | `flutter.yaml` | PRs + push to main | `lint` (global), `changes` (path detection), `test` (dynamic matrix) |
| Build Web | `build-web.yaml` | Push to main only | `build` (flutter build web) |
| Secret Scan | `secrets.yaml` | PRs + push to main | `scan` (gitleaks + trufflehog) |

## Changes Required

### `flutter.yaml`

1. **`changes` job**: Add 7 new path filters (agent, cli, interpreter_monty, schema, scripting, skills, tui) with transitive deps
2. **`changes` job**: Add 7 new matrix entries in the `set-matrix` step
3. **`test` job**: Add per-package `dart format` + `dart analyze` + `dart doc --dry-run` steps (scoped to working directory)
4. **`test` job**: Conditional `fetch-depth` — full history only for `app` (diff-cover), shallow clone for all others
5. **`lint` job**: Remove Dart format/analyze/doc steps (now handled per-package in test matrix). Keep only markdown linting.

### `setup-dart-env/action.yaml`

1. **Use `dart-lang/setup-dart` for dart-only packages** instead of full Flutter SDK — faster install, smaller download

### Additional optimizations (from Gemini review)

1. **Cache pip installs**: Use `actions/setup-python` with `cache: 'pip'` for `diff-cover`/`lcov_cobertura` and `pymarkdownlnt`

### Files unchanged

- `build-web.yaml` — already separated (PR #39)
- `secrets.yaml` — already consolidated (PR #38), already runs on PRs + main
