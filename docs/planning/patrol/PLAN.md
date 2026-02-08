# Patrol E2E Integration - Plan

## Strategy

Get to a working Patrol E2E test as fast as possible. Start with
`--no-auth-mode` to eliminate auth complexity, prove the toolchain, then layer
on OIDC and CI. Leverage the existing logging system (`soliplex_logging`) for
white-box observability, event-driven waits, and self-documenting failures.

## Phases

| Phase | Focus | Auth | Outcome |
|-------|-------|------|---------|
| **A** | [Setup + Smoke](./phase-a-setup-smoke.md) | no-auth | Patrol runs, app boots with logging, backend reachable |
| **B** | [Live Chat](./phase-b-live-chat.md) | no-auth | Rooms load, chat send/receive with log-driven waits |
| **C** | [OIDC + CI](./phase-c-oidc-ci.md) | oidc | Token-seeded auth via ROPC |
| **D** | [Log Hardening](./phase-d-log-hardening.md) | both | Error sentinels, perf bounds, HTTP audit, negative assertions |

## Dependency Graph

```text
Phase A (Setup + Smoke + TestLogHarness)
└── Phase B (Live Chat, log-driven waits)
    └── Phase C (OIDC auth via ROPC)
        └── Phase D (Log hardening: sentinels, perf, audit)
```

## Progress

- [x] Phase A — Setup + Smoke
- [x] Phase B — Live Chat (no-auth)
- [x] Phase C — OIDC auth via ROPC
- [ ] Phase D — Log Hardening

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

### Logging as Test Infrastructure

The `soliplex_logging` package provides white-box observability inside E2E
tests. This is the key differentiator of our Patrol rig:

| Capability | Logging Component | Phase |
|------------|-------------------|-------|
| Event-driven waits (replace polling) | `MemorySink.onRecord` stream | A, B |
| Internal pipeline assertions | `MemorySink.records` query | B |
| Auto-diagnostics on failure | `MemorySink` dump (last 2000 records) | A |
| Logfire correlation (`testRunId`) | `LogSanitizer` attribute injection | C |
| CI failure artifacts | `logs.jsonl` + breadcrumbs bundle | C |
| Performance regression detection | `LogRecord.timestamp` diffs | Future |

### Logging Exploitation Levels

```text
Level 1: Free observation (read existing Loggers.* calls)      ← Phase A
Level 2: Event-driven waits (MemorySink.onRecord stream)       ← Phase B
Level 3: Structured event assertions (attribute-based)          ← Phase B
Level 4: Logfire correlation (testRunId across client+server)   ← Phase C
Level 5: Error sentinels (expectNoErrors across all tests)       ← Phase D
Level 6: Negative/audit assertions (HTTP 401, auth restore)     ← Phase D
Level 7: Performance regression detection (timestamp diffs)     ← Phase D
```

### Streaming-Safe Pumping

`pumpAndSettle()` hangs on SSE streams. Phase A uses condition-based polling
via `waitForCondition`. Phase B upgrades to log-driven waits via
`harness.waitForLog()` where possible.

### Minimal Harness, Grown Incrementally

Phase A introduces `TestLogHarness` with just enough to boot the app with
logging and dump diagnostics on failure. Each subsequent phase adds only what
it needs.

## Deferred (Future Phases)

Intentionally deferred until the core test suite is stable:

| Item | Reason to Defer |
|------|-----------------|
| `$.native` browser automation | Blocked by macOS `ASWebAuthenticationSession` |
| Tool calling tests | Add after chat tests are stable |
| Dual auth modes | One mode at a time is fine |
| Dot-separated test IDs | Normal names until >5 tests |
| `integration_test/README.md` | Write when there are real tests to document |
| iOS targeting | Minimal config delta from macOS; add after macOS is green |
| `runStep()` instrumentation | Add when >3 tests need timing |
| Performance regression detection | Add when baseline established |

## Review Gates

Each phase must pass its gates before the next phase begins.
Maximum 3 review/revise cycles per gate.

### Phase A Gates

| Gate | Tool | What |
|------|------|------|
| **Automated** | CLI | `flutter pub get`, `flutter analyze` = 0, `patrol --version`, `patrol doctor`, `flutter test` passes, smoke test green |
| **Logging** | Manual | TestLogHarness initializes MemorySink, failure dumps last N records to console |
| **Gemini Critique** | `read_files` / `gemini-3-pro-preview` | Review pubspec, harness, smoke test, logging_provider against spec |

### Phase B Gates

| Gate | Tool | What |
|------|------|------|
| **Automated** | CLI | `flutter analyze` = 0, both patrol tests green, no `pumpAndSettle` anywhere |
| **Logging** | Manual | `waitForLog()` for SSE completion, `expectLog()` verifies HTTP + ActiveRun, `dumpLogs()` on failure |
| **Gemini Critique** | `read_files` / `gemini-3-pro-preview` | Review test file, harness, config, loggers.dart against spec |
| **Codex Cross-Validation** | `mcp__codex__codex` / `read-only` | Architecture review: does TestLogHarness + log-driven waits hold up? Provider override strategy correct? Anything brittle before adding auth? |

Phase B gets both Gemini AND Codex review because it is the architectural
pivot point — the harness, provider overrides, and log-driven wait pattern
established here carry forward into Phase C and all future tests.

### Phase C Gates

| Gate | Tool | What |
|------|------|------|
| **Automated** | CLI | `flutter analyze` = 0, authenticated test green, no-auth tests still green, CI YAML valid |
| **Logging** | Manual | `testRunId` in all LogRecords, queryable in Logfire with `SOLIPLEX_SHIP_LOGS=true`, failure artifact bundle produced |
| **Gemini Critique** | `read_files` / `gemini-3-pro-preview` | Review auth_notifier, harness, config, authenticated test, CI workflow, logging_provider against spec |
