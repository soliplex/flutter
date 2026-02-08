# Patrol E2E Integration - Plan

## Strategy

Get to a working Patrol E2E test as fast as possible. Start with
`--no-auth-mode` to eliminate auth complexity, prove the toolchain, then layer
on OIDC and CI.

## Phases

| Phase | Focus | Auth | Outcome |
|-------|-------|------|---------|
| **A** | [Setup + Smoke](./phase-a-setup-smoke.md) | no-auth | `patrol test` runs, app boots, backend reachable |
| **B** | [Live Chat](./phase-b-live-chat.md) | no-auth | Rooms load, chat send/receive end-to-end |
| **C** | [OIDC + CI](./phase-c-oidc-ci.md) | oidc | Token-seeded auth, GitHub Actions pipeline |

## Dependency Graph

```text
Phase A (Setup + Smoke)
└── Phase B (Live Chat, no-auth)
    └── Phase C (OIDC + CI)
```

## Progress

- [ ] Phase A — Setup + Smoke
- [ ] Phase B — Live Chat (no-auth)
- [ ] Phase C — OIDC + CI

## Key Design Decisions

### No-Auth First

All initial tests run against a backend in `--no-auth-mode`. This removes every
auth-related concern (Keycloak, tokens, provider overrides) from the critical
path to a working test.

### Token Seeding for OIDC (Not $.native)

When we add OIDC in Phase C, we use **direct Keycloak ROPC token exchange** +
provider override injection. We do NOT fight `ASWebAuthenticationSession` on
macOS — it resists automation by design. `$.native` browser driving is deferred
to a future hardening phase.

**Keycloak requirement:** The test client must have "Direct Access Grants"
enabled. See [Phase C](./phase-c-oidc-ci.md#keycloak-configuration).

### Streaming-Safe Pumping

`pumpAndSettle()` hangs on SSE streams. All tests use condition-based polling:

```dart
await waitForCondition(
  tester,
  condition: () => find.byType(ChatMessageWidget).evaluate().length > 1,
  timeout: Duration(seconds: 30),
);
```

### Minimal Harness

No big shared test base up front. Phase A introduces only what's needed:
`verifyBackendOrFail` and `waitForCondition`. Helpers grow with real
duplication, not speculation.

## Deferred (Future Phases)

Intentionally deferred until the core test suite is stable:

| Item | Reason to Defer |
|------|-----------------|
| `$.native` browser automation | Blocked by macOS `ASWebAuthenticationSession` |
| Tool calling tests | Add after chat tests are stable |
| Screenshot-on-failure wrapper | Add with CI pipeline |
| Dual auth modes | One mode at a time is fine |
| Dot-separated test IDs | Normal names until >5 tests |
| `integration_test/README.md` | Write when there are real tests to document |
| iOS targeting | Minimal config delta from macOS; add after macOS is green |

## Review Process

Each phase gets one Gemini critique (`mcp__gemini__read_files` with
`gemini-3-pro-preview`). Maximum 3 review/revise cycles per phase.
