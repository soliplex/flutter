# Milestone 07: Test Documentation

**Status:** pending
**Depends on:** 05-live-tool-calling-tests

## Objective

Write an `integration_test/README.md` that serves as both developer guide and
LLM-readable test inventory. Any developer (or agent) should be able to discover
what tests exist, how to run them, and what environment they need — including
OIDC setup.

## Pre-flight Checklist

- [ ] Confirm M04 and M05 complete (all tests written)
- [ ] Collect final test file list and test IDs
- [ ] Review local dev setup requirements

## Deliverables

1. **`integration_test/README.md`** — Test inventory and run guide

## Files to Create

- [ ] `integration_test/README.md`

## Implementation Steps

### Step 1: Write README

**File:** `integration_test/README.md`

Structure:

#### Test Inventory

| Test ID | File | Auth | Description |
|---------|------|------|-------------|
| `live.smoke.backend_reachable` | `smoke_test.dart` | no-auth | Backend connectivity |
| `live.oidc.keycloak_login` | `oidc_auth_test.dart` | oidc | Keycloak OIDC login via native |
| `live.rooms.load` | `live_chat_test.dart` | oidc | Room list from authenticated API |
| `live.chat.send_receive` | `live_chat_test.dart` | oidc | Chat message round-trip with SSE |
| `live.tools.client_execution` | `live_tool_calling_test.dart` | oidc | Client-side tool call cycle |

#### Prerequisites

- Flutter SDK (stable channel)
- Patrol CLI (`dart pub global activate patrol_cli`)
- Xcode (macOS — for building and Patrol native interaction)
- CocoaPods (`gem install cocoapods` or via Homebrew)
- Backend running (either `--no-auth-mode` or with Keycloak)
- Keycloak test user provisioned (for OIDC tests)

#### Running Tests

##### No-Auth Mode (Quick Smoke)

```bash
# Start backend in no-auth mode
soliplex-cli serve example/minimal.yaml --no-auth-mode

# Run smoke test
patrol test --target integration_test/smoke_test.dart \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000 \
  --dart-define SOLIPLEX_AUTH_MODE=no-auth
```

##### OIDC Mode (Full Integration)

```bash
# Start backend with Keycloak auth
soliplex-cli serve example/production.yaml

# Run all OIDC tests
patrol test --target integration_test/ \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000 \
  --dart-define SOLIPLEX_AUTH_MODE=oidc \
  --dart-define SOLIPLEX_OIDC_USERNAME=testuser \
  --dart-define SOLIPLEX_OIDC_PASSWORD=testpass

# Run specific test
patrol test --target integration_test/oidc_auth_test.dart \
  --dart-define SOLIPLEX_BACKEND_URL=http://localhost:8000 \
  --dart-define SOLIPLEX_AUTH_MODE=oidc \
  --dart-define SOLIPLEX_OIDC_USERNAME=testuser \
  --dart-define SOLIPLEX_OIDC_PASSWORD=testpass
```

#### Environment Variables (--dart-define)

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `SOLIPLEX_BACKEND_URL` | `http://localhost:8000` | No | Backend API base URL |
| `SOLIPLEX_AUTH_MODE` | `no-auth` | No | `no-auth` or `oidc` |
| `SOLIPLEX_OIDC_USERNAME` | (empty) | OIDC only | Keycloak test user |
| `SOLIPLEX_OIDC_PASSWORD` | (empty) | OIDC only | Keycloak test password |

**Note:** These are compile-time constants via `--dart-define`, not shell
environment variables. `String.fromEnvironment` reads `--dart-define` values.

#### Architecture Notes

- All tests use `patrol_test_base.dart` for shared setup (single import)
- No `pumpAndSettle` — condition-based polling via `waitForCondition` for
  SSE streaming compatibility
- Screenshots captured automatically on failure via `patrolTestWithScreenshot`
- Tests create fresh threads per run (no shared state)
- macOS keyboard assertion workaround applied via `ignoreKeyboardAssertions()`
  (works around a known Flutter macOS keyboard event bug)
- OIDC login driven by Patrol's `$.native` API which interacts with the system
  browser that `flutter_appauth` opens for Keycloak

### Step 2: Lint markdown

- [ ] Run `npx markdownlint-cli integration_test/README.md`
- [ ] Fix any linting issues

## Out of Scope

- API documentation (covered by soliplex_client docs)
- Contributing guidelines (project-level concern)
- Troubleshooting beyond environment setup

## Validation Gate

### Automated Checks

- [ ] `npx markdownlint-cli integration_test/README.md` passes
- [ ] All test IDs in README match actual test implementations
- [ ] Run commands in README are accurate and copy-pasteable

### Review Gate

#### Gemini Critique

**Tool:** `mcp__gemini__read_files`
**Model:** `gemini-3-pro-preview`

**Files:** `integration_test/README.md`,
`docs/planning/patrol/07-test-documentation.md`,
`integration_test/smoke_test.dart`,
`integration_test/oidc_auth_test.dart`,
`integration_test/live_chat_test.dart`,
`integration_test/live_tool_calling_test.dart`

**Prompt:**

```text
Review the integration test README against the spec in
07-test-documentation.md and the actual test files.

Check:
1. Test inventory table matches actual test IDs in files
2. Both auth modes documented with run commands
3. Prerequisites include Xcode, CocoaPods, Keycloak test user
4. --dart-define explained (not shell env vars)
5. Architecture notes mention keyboard workaround and $.native
6. README is LLM-parseable (structured, consistent formatting)

Report PASS or list specific issues to fix.
```

- [ ] Gemini critique: PASS

## Success Criteria

- [ ] README covers all test IDs from M02-M05
- [ ] Both auth modes documented with full run commands
- [ ] `--dart-define` usage explained clearly
- [ ] Prerequisites include Xcode, CocoaPods, Keycloak test user
- [ ] Markdown linting passes
- [ ] Any developer can set up and run tests from README alone
- [ ] Gemini critique: PASS
