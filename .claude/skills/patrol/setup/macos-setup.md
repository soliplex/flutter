# macOS Patrol Setup & Constraints

## Window size is fixed (~800x600)

The macOS test window runs BELOW the 840px desktop breakpoint
(`SoliplexBreakpoints.desktop`). This means:

- **HistoryPanel renders in the drawer**, not as an inline sidebar
- `WidgetTester.setSurfaceSize()` does NOT work in integration tests
  (real macOS window, not test binding)
- To access drawer content, tap the hamburger menu icon first
- After tapping a button inside a drawer, the drawer does NOT auto-close

**Strategy:** Avoid drawer interactions when possible. The ChatPanel body
renders regardless of drawer state, and threads auto-select when entering
a room.

## Entitlements

Both the app AND the test runner need their own entitlements:

| Binary | Entitlements file | Required keys |
|--------|-------------------|---------------|
| Runner (app) | `macos/Runner/DebugProfile.entitlements` | `network.client`, `network.server` |
| RunnerUITests | `macos/RunnerUITests/RunnerUITests.entitlements` | `network.client`, `network.server`, `app-sandbox` |

**Debugging:** `codesign -d --entitlements :- <path-to-binary>` shows actual
signed entitlements.

**After changing entitlements**, re-approve Accessibility permissions in
System Settings.

## Keyboard assertions

macOS has a Flutter keyboard assertion bug. All tests must call
`ignoreKeyboardAssertions()` early. On web, the function is a no-op
(`kIsWeb` guard).
