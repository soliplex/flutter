# Contributing to Soliplex Flutter

## Branch Naming

- `feat/<name>` -- New features
- `fix/<issue>` -- Bug fixes
- `refactor/<area>` -- Code restructuring
- `docs/<topic>` -- Documentation changes

## Commit Format

```text
<type>(<scope>): <description>

<body — what changed and why>
```

**Types:** `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

**Example:**

```text
feat(agent): add multi-server runtime support

Add ServerConnection, ServerRegistry, and AgentRuntime.fromConnection
to support concurrent connections to multiple Soliplex servers.
```

## Pull Request Process

1. Create a branch off `main` using the naming convention above.
2. Make your changes, ensuring all checks pass (see below).
3. Push and open a PR against `main`.

**PR title:** `<type>(<scope>): <title>` (matches commit format).

**PR body:**

```text
## Summary
- Bullet points

## Changes
- **Component**: Description

## Test plan
- [x] Manual steps
- [x] Automated pass
```

## Pre-Commit Hooks

This repo uses [pre-commit](https://pre-commit.com/) to enforce code quality.

### Setup

```bash
# Install pre-commit (once)
pip install pre-commit   # or: brew install pre-commit

# Install hooks into this repo
pre-commit install
```

### What Runs

| Hook | What it does |
|------|-------------|
| `no-commit-to-branch` | Blocks direct commits to `main`/`master` |
| `check-merge-conflict` | Catches unresolved merge markers |
| `gitleaks` | Scans for leaked secrets |
| `dart-format` | Enforces `dart format` on all `.dart` files |
| `flutter-analyze` | Runs `dart analyze --fatal-infos` on app `lib/` and `test/` |
| `dcm-analyze` | Runs DCM analysis on `lib/` (optional — skips if `dcm` is not installed) |
| `dart-analyze-packages` | Runs `dart analyze --fatal-infos` on all 12 packages |
| `pymarkdown` | Lints all Markdown files |

### DCM (Optional but Recommended)

[DCM](https://dcm.dev) (Dart Code Metrics) provides additional static analysis
beyond what `dart analyze` covers. It is **optional** for local development —
the pre-commit hook skips gracefully if `dcm` is not installed.

CI enforces DCM, so install it locally to catch issues early:

```bash
# macOS
brew install nicklockwood/formulae/dcm

# Other platforms: see https://dcm.dev/docs/getting-started/
```

## Testing

### Per-Package

```bash
cd packages/<package_name>

# Pure Dart packages
dart pub get
dart test
dart format . --set-exit-if-changed
dart analyze --fatal-infos

# Flutter packages (soliplex_client_native, soliplex_monty)
flutter pub get
flutter test
dart format . --set-exit-if-changed
dart analyze --fatal-infos
```

### App-Level

```bash
# From repo root
flutter pub get
flutter test
dart format . --set-exit-if-changed
dart analyze --fatal-infos lib/ test/
```

### Coverage Target

Aim for 85%+ coverage on new and changed code.

## Code Style

- Linting: `very_good_analysis` (all packages)
- Formatting: `dart format` (enforced by pre-commit)
- No `// ignore:` directives — restructure code instead
- Pure Dart packages must not import `package:flutter/*`
- Platform-specific code goes in `soliplex_client_native`
- See [docs/rules/flutter_rules.md](docs/rules/flutter_rules.md) for full
  conventions
