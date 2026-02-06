# Patrol E2E Integration - Milestone Overview

## Strategy

This plan prioritizes **OIDC authentication early**. Patrol's native interaction
capability (`$.native`) is the primary reason for adopting it — we need to drive
Keycloak login popups via the system browser that `app_auth` opens. The plan
supports two test modes: no-auth for fast local smoke tests, and OIDC for full
integration against a Keycloak-protected backend.

## Key Design Decisions

### Dual Auth Modes

Tests support two backend configurations:

| Mode | Use Case | Backend Flag | Auth |
|------|----------|-------------|------|
| **no-auth** | Local smoke tests | `--no-auth-mode` | `_NoAuthNotifier` override |
| **oidc** | Full integration | Standard | Patrol `$.native` drives Keycloak login |

```dart
// Mode selection via environment
const authMode = String.fromEnvironment(
  'SOLIPLEX_AUTH_MODE',
  defaultValue: 'no-auth',
);
```

### Live Backend Testing (No Mocks)

All Patrol tests connect to a real backend. No-auth mode skips login; OIDC mode
drives the full Keycloak flow via Patrol's native interaction.

```dart
// Backend URL from compile-time constant (--dart-define)
const backendUrl = String.fromEnvironment(
  'SOLIPLEX_BACKEND_URL',
  defaultValue: 'http://localhost:8000',
);
```

### Keycloak OIDC via Patrol Native

Patrol's `$.native` API interacts with the system browser that `flutter_appauth`
opens for Keycloak authentication:

```dart
// Patrol drives the Keycloak login form in the system browser
await $.native.enterTextByIndex(username, index: 0);
await $.native.enterTextByIndex(password, index: 1);
await $.native.tap(Selector(text: 'Sign In'));
```

### Streaming-Safe Pumping

`pumpAndSettle()` hangs on SSE streams. All tests use condition-based polling:

```dart
await waitForCondition(
  tester,
  condition: () => find.byType(ChatMessageWidget).evaluate().length > 1,
  timeout: Duration(seconds: 30),
);
```

### Dot-Separated Test IDs

Test names use structured IDs for LLM-parseable test inventories:

- `live.smoke.backend_reachable`
- `live.oidc.keycloak_login`
- `live.rooms.load`
- `live.chat.send_receive`
- `live.tools.client_execution`

## Progress

- [ ] 01-patrol-setup
- [ ] 02-test-infrastructure
- [ ] 03-oidc-auth-flow
- [ ] 04-live-chat-tests
- [ ] 05-live-tool-calling-tests
- [ ] 06-ci-pipeline
- [ ] 07-test-documentation

## Review Process

Each milestone must pass one review before completion:

1. **Gemini Critique** - Use `mcp__gemini__read_files` with model
   `gemini-3-pro-preview`, passing the milestone spec and all related files

**Iteration Limit:** Maximum 3 review/revise cycles per milestone.
**File Limit:** 15 files per Gemini call. Batch if needed.

## Milestones

### 01-patrol-setup

- **Focus:** Dependencies & Configuration
- **Objective:** Add Patrol packages, configure `pubspec.yaml` patrol section,
  verify CLI installation.
- **Outcome:** `patrol test` command is available and project compiles.
- **File:** [01-patrol-setup.md](./01-patrol-setup.md)

---

### 02-test-infrastructure

- **Focus:** Shared Test Plumbing
- **Depends on:** 01-patrol-setup
- **Objective:** Create `patrol_test_base.dart` with backend preflight, streaming
  helpers, screenshot-on-failure wrapper, dual-mode auth (no-auth + OIDC), and
  macOS keyboard workaround.
- **Outcome:** A reusable test harness that any Patrol test can import.
- **File:** [02-test-infrastructure.md](./02-test-infrastructure.md)

---

### 03-oidc-auth-flow

- **Focus:** Keycloak Authentication via Patrol Native
- **Depends on:** 02-test-infrastructure
- **Objective:** Implement `live.oidc.keycloak_login` test that drives the
  `flutter_appauth` / Keycloak login popup using Patrol's `$.native` API.
- **Outcome:** Tests can authenticate against a Keycloak-protected backend.
- **File:** [03-oidc-auth-flow.md](./03-oidc-auth-flow.md)

---

### 04-live-chat-tests

- **Focus:** Core User Flow (Authenticated)
- **Depends on:** 03-oidc-auth-flow
- **Objective:** Implement `live.rooms.load` and `live.chat.send_receive` tests
  against a Keycloak-protected backend after OIDC login.
- **Outcome:** Room listing and chat round-trip verified end-to-end with auth.
- **File:** [04-live-chat-tests.md](./04-live-chat-tests.md)

---

### 05-live-tool-calling-tests

- **Focus:** AG-UI Tool Execution (Authenticated)
- **Depends on:** 03-oidc-auth-flow
- **Objective:** Implement `live.tools.client_execution` test verifying client-side
  tool call processing and continuation runs.
- **Outcome:** Tool call flow verified end-to-end with auth.
- **File:** [05-live-tool-calling-tests.md](./05-live-tool-calling-tests.md)

---

### 06-ci-pipeline

- **Focus:** Automation
- **Depends on:** 04-live-chat-tests, 05-live-tool-calling-tests
- **Objective:** Create GitHub Actions workflow for Patrol tests on macOS with
  OIDC test credentials, screenshot artifact upload on failure, and backend
  health check.
- **Outcome:** Integration tests run automatically on push/PR.
- **File:** [06-ci-pipeline.md](./06-ci-pipeline.md)

---

### 07-test-documentation

- **Focus:** Developer Enablement
- **Depends on:** 05-live-tool-calling-tests
- **Objective:** Write `integration_test/README.md` with test inventory, run
  instructions, OIDC setup, and environment variable guide.
- **Outcome:** Any developer (or LLM) can discover and run tests.
- **File:** [07-test-documentation.md](./07-test-documentation.md)

---

## Dependency Graph

```text
01-patrol-setup
└── 02-test-infrastructure
    ├── (no-auth smoke test)
    └── 03-oidc-auth-flow
        ├── 04-live-chat-tests ──┐
        │                        ├── 06-ci-pipeline
        └── 05-live-tool-calling-tests
            └── 07-test-documentation
```

## Platform Scope

Initial target: **macOS** only (primary dev platform).

| Test | macOS |
|------|-------|
| Patrol CLI runs | [ ] |
| Backend preflight passes | [ ] |
| Keycloak OIDC login via native | [ ] |
| Room list loads (authenticated) | [ ] |
| Chat send/receive works | [ ] |
| Tool calling works | [ ] |
| Screenshots captured on failure | [ ] |
| CI pipeline passes | [ ] |

Future: iOS, Android (requires bundle ID / package name config).

## Notes

- Started: 2026-02-06
- Restructured: 2026-02-06 (OIDC moved early, Keycloak + app_auth)
- Source analysis: [patrol-analysis.md](../../patrol-analysis.md)
- OIDC provider: Keycloak (via `flutter_appauth` / `app_auth`)
- Two auth modes: no-auth (local smoke) + OIDC (full integration)
- No mock backends — all tests hit real API
- Reuses existing provider override pattern from `integration_test/`
