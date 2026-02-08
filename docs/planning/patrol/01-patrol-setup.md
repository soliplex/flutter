# Milestone 01: Patrol Package Setup

**Status:** pending
**Depends on:** none

## Objective

Install Patrol dependencies, add patrol configuration to `pubspec.yaml`, and
verify the `patrol` CLI is functional. After this milestone the project compiles
with Patrol and `patrol test` is a valid command.

## Pre-flight Checklist

- [ ] Confirm `integration_test/` directory exists
- [ ] Confirm `integration_test` SDK dependency already in pubspec.yaml
- [ ] Verify macOS bundle ID is `ai.soliplex.client`
- [ ] Check current Patrol version on pub.dev

## Deliverables

1. **pubspec.yaml changes**: Patrol dev dependencies and patrol config section
2. **CLI availability**: `patrol_cli` globally activated

## Implementation Steps

### Step 1: Add Patrol dev dependencies

**File:** `pubspec.yaml`

- [ ] Add `patrol: ^4.3.0` to dev_dependencies
- [ ] Add `patrol_finders: ^3.0.0` to dev_dependencies
- [ ] Run `flutter pub get` to verify resolution

### Step 2: Add Patrol configuration section

**File:** `pubspec.yaml`

- [ ] Add top-level `patrol:` configuration block:

```yaml
patrol:
  app_name: Soliplex
  test_directory: integration_test
  macos:
    bundle_id: ai.soliplex.client
  ios:
    bundle_id: ai.soliplex.client
```

### Step 3: Install Patrol CLI

- [ ] Run `dart pub global activate patrol_cli`
- [ ] Verify `patrol --version` outputs version info
- [ ] Verify `patrol doctor` reports no blocking issues

### Step 4: Verify compilation

- [ ] Run `flutter analyze --fatal-infos` — zero issues
- [ ] Run `flutter build macos --debug --no-pub` — compiles successfully
- [ ] Confirm existing integration tests still compile

## Out of Scope

- Writing any test files (deferred to M02-M05)
- Android package name configuration
- Patrol native test runner setup (uses default Flutter driver)

## Validation Gate

### Automated Checks

- [ ] `flutter pub get` succeeds
- [ ] `flutter analyze --fatal-infos` reports 0 issues
- [ ] `patrol --version` outputs version
- [ ] `patrol doctor` reports no blocking issues
- [ ] `flutter build macos --debug --no-pub` compiles
- [ ] Existing `flutter test` suite still passes

### Review Gate

#### Gemini Critique

**Tool:** `mcp__gemini__read_files`
**Model:** `gemini-3-pro-preview`

**Files:** `pubspec.yaml`, `docs/planning/patrol/01-patrol-setup.md`,
`docs/patrol-analysis.md`

**Prompt:**

```text
Review the Patrol setup in pubspec.yaml against the spec in
01-patrol-setup.md and the source analysis in patrol-analysis.md.

Check:
1. Patrol dependency version is current (^4.3.0 or newer)
2. patrol_finders included as recommended
3. Patrol config section has correct bundle IDs
4. No conflicts with existing integration_test setup
5. No unnecessary dependencies added

Report PASS or list specific issues to fix.
```

- [ ] Gemini critique: PASS

## Success Criteria

- [ ] Patrol packages resolve in pubspec.yaml
- [ ] Patrol config section present with correct bundle IDs
- [ ] `patrol --version` works
- [ ] `patrol doctor` clean
- [ ] `flutter build macos --debug` compiles
- [ ] Zero analyzer issues
- [ ] Existing tests unaffected
