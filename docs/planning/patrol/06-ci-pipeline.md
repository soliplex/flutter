# Milestone 06: CI Pipeline

**Status:** pending
**Depends on:** 04-live-chat-tests, 05-live-tool-calling-tests

## Objective

Create a GitHub Actions workflow that runs Patrol integration tests on macOS,
provides OIDC test credentials, uploads screenshot artifacts on failure, and
includes a backend health check before expensive test execution.

## Pre-flight Checklist

- [ ] Confirm M04 and M05 complete (chat + tool tests passing locally)
- [ ] Review existing `.github/workflows/` for CI patterns
- [ ] Verify staging backend URL is available as a GitHub secret
- [ ] Verify Keycloak test user credentials are available as GitHub secrets
- [ ] Confirm `macos-latest` runner supports Flutter and Patrol

## Deliverables

1. **`.github/workflows/patrol-integration.yml`** — GitHub Actions workflow

## Files to Create

- [ ] `.github/workflows/patrol-integration.yml`

## Implementation Steps

### Step 1: Create workflow file

**File:** `.github/workflows/patrol-integration.yml`

```yaml
name: Patrol Integration Tests

on:
  push:
    branches: [main, feat/patrol-integration]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  integration-test:
    runs-on: macos-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Install Patrol CLI
        run: |
          dart pub global activate patrol_cli
          echo "$HOME/.pub-cache/bin" >> $GITHUB_PATH

      - name: Install dependencies
        run: flutter pub get

      - name: Install CocoaPods
        run: pod install --project-directory=macos

      - name: Backend health check
        env:
          SOLIPLEX_BACKEND_URL: ${{ secrets.STAGING_BACKEND_URL }}
        run: |
          curl -f -s --connect-timeout 10 \
            "$SOLIPLEX_BACKEND_URL/api/login" || \
            (echo "::error::Backend unreachable at $SOLIPLEX_BACKEND_URL" && exit 1)

      - name: Run Patrol tests (OIDC)
        run: |
          patrol test \
            --target integration_test/oidc_auth_test.dart \
            --target integration_test/live_chat_test.dart \
            --target integration_test/live_tool_calling_test.dart \
            --dart-define SOLIPLEX_BACKEND_URL=${{ secrets.STAGING_BACKEND_URL }} \
            --dart-define SOLIPLEX_AUTH_MODE=oidc \
            --dart-define SOLIPLEX_OIDC_USERNAME=${{ secrets.OIDC_TEST_USERNAME }} \
            --dart-define SOLIPLEX_OIDC_PASSWORD=${{ secrets.OIDC_TEST_PASSWORD }}

      - name: Upload screenshots on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: patrol-screenshots
          path: build/patrol/screenshots/
          retention-days: 7
```

**Key fixes from round 1 critique:**

- `$HOME/.pub-cache/bin` added to `$GITHUB_PATH` so `patrol` is found
- `--dart-define` used instead of shell env vars (required by
  `String.fromEnvironment`)
- Backend health check step before expensive test execution
- OIDC credentials passed via secrets

### Step 2: Document required secrets

| Secret | Description |
|--------|-------------|
| `STAGING_BACKEND_URL` | Backend API base URL (e.g., `https://staging.soliplex.ai`) |
| `OIDC_TEST_USERNAME` | Keycloak test user username |
| `OIDC_TEST_PASSWORD` | Keycloak test user password |

- [ ] All three secrets configured in GitHub repository settings
- [ ] Backend at staging URL has Keycloak auth enabled
- [ ] Keycloak test user has access to at least one room

### Step 3: Verify workflow syntax

- [ ] Validate YAML syntax
- [ ] Confirm `workflow_dispatch` allows manual triggering for debugging
- [ ] Confirm `patrol_test_base.dart` does not end in `_test.dart` (won't be
  picked up as a test file)

## CI OIDC Strategy

**Known risk:** macOS CI runners may not have TCC (Transparency, Consent, and
Control) permissions required for Patrol `$.native` to interact with
`ASWebAuthenticationSession`. If M03's primary approach (native browser
interaction) does not work in CI:

- **Use the fallback approach** from M03: direct Keycloak token exchange +
  mock injection. This bypasses the system browser entirely while still
  running tests against the real authenticated backend.
- The fallback is CI-safe because it makes a direct HTTP call to Keycloak's
  token endpoint (Resource Owner Password Credentials grant) and injects
  the resulting tokens into the app's auth state.

## Out of Scope

- Backend deployment/provisioning in CI (assumes backend is already running)
- iOS/Android CI runners
- Parallel test execution across platforms
- Test result reporting beyond pass/fail and screenshots
- Slack/email notifications
- TCC permission automation (manual runner config if native approach needed)

## Validation Gate

### Automated Checks

- [ ] YAML syntax is valid
- [ ] Workflow triggers on correct branches
- [ ] Screenshot upload only triggers on failure
- [ ] `--dart-define` used for all compile-time constants

### Review Gate

#### Gemini Critique

**Tool:** `mcp__gemini__read_files`
**Model:** `gemini-3-pro-preview`

**Files:** `.github/workflows/patrol-integration.yml`,
`docs/planning/patrol/06-ci-pipeline.md`,
`docs/patrol-analysis.md`

**Prompt:**

```text
Review the Patrol CI pipeline against the spec in
06-ci-pipeline.md and source analysis in patrol-analysis.md.

Check:
1. Workflow triggers on correct branches and events
2. Flutter and Patrol CLI setup steps are correct
3. $HOME/.pub-cache/bin added to GITHUB_PATH
4. --dart-define used for String.fromEnvironment constants
5. OIDC credentials passed via secrets (not hardcoded)
6. Backend health check runs before tests
7. Screenshot artifacts uploaded only on failure
8. Timeout is reasonable (30 minutes)

Report PASS or list specific issues to fix.
```

- [ ] Gemini critique: PASS

## Success Criteria

- [ ] Workflow YAML is valid and well-structured
- [ ] Triggers on push to main, PRs, and manual dispatch
- [ ] Backend health check fails fast if staging is down
- [ ] `--dart-define` passes all compile-time constants
- [ ] OIDC credentials via secrets (never in YAML)
- [ ] Screenshot artifacts uploaded on failure
- [ ] Gemini critique: PASS
