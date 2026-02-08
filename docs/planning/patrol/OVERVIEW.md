# Patrol E2E Integration - Overview

## What

End-to-end integration tests for the Soliplex Flutter frontend using
[Patrol](https://pub.dev/packages/patrol) by LeanCode. Tests run against a live
backend (no mocks) and verify the full user flow from app launch through chat
interaction.

## Why Patrol

Standard `integration_test` cannot interact with native UI outside the Flutter
widget tree. Patrol adds:

- **`$.native` API** — drives system dialogs, browser popups, permission prompts
- **Custom finders** — cleaner syntax (`$('text')`) alongside standard finders
- **CLI tooling** — `patrol test` with hot restart, device targeting, screenshots
- **Future-proofing** — OIDC popups, location permissions, share sheets

## Platform Support

| Platform | `patrol test` | `$.native` | Notes |
|----------|:---:|:---:|-------|
| **macOS** | yes | yes | Primary target. Uses Accessibility APIs. |
| **iOS** | yes | yes | Uses XCUITest. Bundle ID already configured. |
| **Web** | no | no | Patrol relies on native UI frameworks. Use `integration_test` + ChromeDriver for web E2E. |

Initial scope: **macOS only**. iOS requires minimal additional config (same
bundle ID `ai.soliplex.client`).

## Current State

### Existing Infrastructure

- `integration_test/` directory does not exist yet
- `integration_test` SDK dependency missing from `pubspec.yaml`
- macOS bundle ID: `ai.soliplex.client`
- macOS entitlements include `com.apple.security.network.client`
- Test helpers in `test/helpers/test_helpers.dart` (mock factories, `pumpWithProviders`)

### API Endpoints (from soliplex_client)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/rooms` | GET | List rooms |
| `/api/v1/rooms/{roomId}/agui` | GET | List threads |
| `/api/v1/rooms/{roomId}/agui` | POST | Create thread |
| `/api/v1/rooms/{roomId}/agui/{threadId}` | POST | Create run (starts SSE) |
| `/api/login` | GET | Auth provider config (Keycloak) |

## Source Analysis

Detailed analysis of Patrol requirements, test architecture recommendations,
and code patterns: [patrol-analysis.md](../../patrol-analysis.md)

## History

- 2026-02-06 — Initial 7-milestone plan created
- 2026-02-06 — 3x Gemini critique + 1x Codex review of original plan
- 2026-02-07 — Simplified to 3 phases after Codex + Gemini cross-validation
- 2026-02-07 — Scoped to `--no-auth-mode` first for fastest value
