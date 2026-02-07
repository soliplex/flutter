# Milestone 12.3 — App Integration

**Phase:** 1 — Core (P0)\
**Status:** Pending\
**Blocked by:** 12.2\
**PR:** —

---

## Goal

Wire `BackendLogSink` into the Flutter app via Riverpod providers. Add
Telemetry screen for enable/disable. All platforms use the same endpoint.

---

## Changes

### Config

**`lib/core/logging/log_config.dart`:**

- Add `backendLoggingEnabled` (bool, default false)
- Add `backendEndpoint` (String, default `/api/v1/logs`).
  **Locked in production builds** — editable only in debug/dev to
  prevent misconfiguration or exfiltration risk

### Providers

**`lib/core/logging/logging_provider.dart`:**

- Add `installIdProvider` — per-install UUID, persisted to local storage
  on first launch. Stable "device Y" key for cross-session queries.
- Add `backendLogSinkProvider` — creates `BackendLogSink` with:
  - Endpoint from config
  - `http.Client` from platform client provider
  - `installId` from `installIdProvider`
  - `sessionId` from new `sessionIdProvider` (UUID, generated once)
  - `userId` from auth state provider
  - `resourceAttributes` from `package_info_plus` + `device_info_plus`
  - `networkChecker` from `connectivity_plus`
  - `DiskQueue` with path from `path_provider`
  - `memorySink` from `memorySinkProvider` — injected so
    `BackendLogSink` can read breadcrumbs on ERROR/FATAL (12.5).
    Sinks are siblings under `LogManager`, so `BackendLogSink` has
    no implicit access to `MemorySink` — it must be injected.
- Wire `LogSanitizer` with default security-appropriate rules via
  `LogManager.instance.sanitizer = ...` (property setter, not
  constructor — `LogManager` is a `static final` singleton)
- Register with `LogManager`, `ref.onDispose → close`
- Sink disabled when `backendLoggingEnabled` is false

### Lifecycle flush

- **Mobile:** `AppLifecycleListener` → `flush()` on `paused`
- **Desktop:** `AppLifecycleListener` → `flush()` on `hidden`/`detached`
- **Web:** `visibilitychange` → `flush()` when `document.hidden`

### Session start marker

On app startup (after providers initialize), emit a single `info`-level
log with attributes: `app_version`, `build_number`, `os_name`,
`os_version`, `device_model`, `dart_version`. This is the first record
in every session — gives support a device fingerprint per session.

### Connectivity listener

Subscribe to `connectivity_plus` stream. On connectivity change, emit
`info`-level log: `network_changed` with attributes `type`
(wifi/cellular/none) and `online` (bool). Support needs to know if the
device was offline *when* the error occurred, not just at flush time.

### Dart crash hooks

Set up `PlatformDispatcher.instance.onError` and
`FlutterError.onError` in app initialization (before `runApp`)

### Telemetry screen

**`lib/features/settings/telemetry_screen.dart` (new):**

- Enable/disable toggle
- Endpoint field (pre-filled, **read-only in production builds**,
  editable in debug/dev only — exfiltration prevention)
- Connection status indicator
- No token field needed (backend holds Logfire token)

**`lib/core/router/`:**

- Add route for Telemetry screen

---

## Dependencies (App Layer Only)

- `connectivity_plus` — `NetworkStatusChecker` callback + change listener
- `package_info_plus` — `service.version` resource attribute
- `device_info_plus` — `device.model`, `os.version` resource attributes
- `path_provider` — `DiskQueue` file location
- `uuid` — installId + sessionId generation
- `shared_preferences` — persist `installId` across installs

---

## Unit Tests

- `test/core/logging/logging_provider_test.dart`:
  - BackendLogSink created when enabled
  - Sink not created when disabled
  - InstallId persisted across app launches (same install)
  - SessionId persists across provider rebuilds (same session)
  - UserId updates when auth state changes
  - Disposed on ref dispose

---

## Widget Tests

- `test/features/settings/telemetry_screen_test.dart`:
  - Toggle enables/disables export
  - Connection status reflects sink state
  - Endpoint field read-only in production mode
  - Endpoint field editable in debug mode

---

## Integration Tests

- `test/integration/backend_toggle_flow_test.dart` — Toggle backend
  logging off → sink unregistered. Toggle on → re-registered. Verify
  logs stop/start flowing.
- `test/integration/backend_lifecycle_flush_test.dart` — Write records,
  simulate `AppLifecycleState.paused`, verify flush called.

---

## Acceptance Criteria

- [ ] `backendLogSinkProvider` creates sink with all injected deps
- [ ] `installId` persisted per-install, included in every payload
- [ ] SessionId generated on startup, injected into every payload
- [ ] UserId from auth state, nullable for pre-auth logs
- [ ] Config toggle enables/disables at runtime
- [ ] Session start marker emitted on startup with device/app attributes
- [ ] Connectivity listener logs `network_changed` events
- [ ] Lifecycle flush on all platforms
- [ ] Dart crash hooks wired before `runApp`
- [ ] Telemetry screen with toggle, endpoint (locked in prod), status
- [ ] `connectivity_plus` integration (flush check + change listener)
- [ ] `LogSanitizer` wired into `LogManager` (all sinks sanitized)

---

## Gates

All gates must pass before the milestone PR can merge.

### Automated

- [ ] **Format:** `dart format --set-exit-if-changed .` — zero changes
- [ ] **Analyze:** `dart analyze` — zero issues (errors, warnings, hints)
- [ ] **Unit tests:** all pass, coverage ≥ 85% for changed files
- [ ] **Integration tests:** all pass

### Gemini Review (up to 3 iterations)

Pass this file and all changed `.dart` source files to Gemini Pro 3
via `mcp__gemini__read_files` (model: `gemini-3-pro-preview`).

- [ ] Gemini passes with no blockers (or issues resolved within 3 iterations)
