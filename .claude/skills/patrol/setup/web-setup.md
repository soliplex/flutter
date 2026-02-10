# Chrome (Web) Patrol Setup & Constraints

## Viewport is controllable

Unlike macOS (fixed ~800x600), Chrome viewport can be set with
`--web-viewport "1280x720"`. A viewport >= 840px wide puts the app above
the desktop breakpoint, so the HistoryPanel renders inline instead of in
a drawer.

## No entitlements required

Web does not require macOS entitlements or Accessibility permissions.

## CORS

The backend must return proper CORS headers for the test origin. Default
dev server config at `localhost:8000` typically handles this.

## Node.js required

Patrol uses Playwright for Chrome automation. Playwright requires
Node.js >= 18. It auto-installs browser binaries on first
`patrol test --device chrome` run.
