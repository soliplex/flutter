# 09 - HTTP Inspector

## Overview

Debug tooling for HTTP traffic inspection. Captures network events from the HTTP
client, correlates requests with responses, and provides detailed analysis views.
Implements Observer pattern with ephemeral state (never persisted for security).

## Files

| File | Purpose |
|------|---------|
| `lib/core/providers/http_log_provider.dart` | Central event store with HttpObserver |
| `lib/features/inspector/http_inspector_panel.dart` | Compact debug drawer widget |
| `lib/features/inspector/models/http_event_group.dart` | Request/response correlation DTO |
| `lib/features/inspector/models/http_event_grouper.dart` | Event grouping logic |
| `lib/features/inspector/network_inspector_screen.dart` | Full-screen analysis view |
| `lib/features/inspector/widgets/http_event_tile.dart` | Request list item |
| `lib/features/inspector/widgets/http_status_display.dart` | Status badge/spinner |
| `lib/features/inspector/widgets/request_detail_view.dart` | Tabbed detail view |

## Public API

### Provider (http_log_provider.dart)

- `HttpLogNotifier` - Central store implementing `HttpObserver`
  - `onRequest`, `onResponse`, `onError`, `onStreamStart`, `onStreamEnd` - Event ingestion
  - `clear()` - Reset log
  - Max 500 events; uses `scheduleMicrotask` for build-safe updates
- `httpLogProvider` - Riverpod provider instance

### Models

**`HttpEventStatus`** (enum) - Request state (pending, success, error, streaming)

**`HttpEventGroup`** - Correlated request/response DTO

- `methodLabel`, `pathWithQuery`, `status` - Display getters
- `toCurl()` - Generate cURL command
- `formatBody()` - JSON pretty-print utility

**`groupHttpEvents(List<HttpEvent>)`** - Pure grouping function

### Screens

**`HttpInspectorPanel`** - Compact widget for debug drawer

**`NetworkInspectorScreen`** - Full-screen with master-detail layout

### Widgets

- `HttpEventTile` - List item (method, path, time, status)
- `HttpStatusDisplay` - Visual status badge with theme-adapted colors
- `RequestDetailView` - Tabbed view (Request/Response/cURL)

## Dependencies

### External Packages

- `flutter_riverpod` - State management
- `go_router` - Navigation
- `meta` - Annotations (`@doNotStore`)

### Internal Dependencies

| Domain | Imports |
|--------|---------|
| Client Package | `HttpObserver`, event classes |
| Design | Theme, breakpoints, spacing |
| Shared | `AppShell`, `ShellConfig` |

## Data Flow

### Event Ingestion

```text
1. ObservableHttpClient calls HttpLogNotifier methods
2. Events sanitized/redacted before reaching this layer
3. Notifier wraps state update in scheduleMicrotask
4. Event appended; oldest sliced if > 500
```

### Transformation & Rendering

```text
1. UI widgets watch httpLogProvider
2. groupHttpEvents transforms flat list to HttpEventGroup objects
3. Groups sorted by timestamp
4. NetworkInspectorScreen renders list (mobile) or split-view (tablet)
5. RequestDetailView computes JSON formatting, cURL lazily
```

## Architectural Patterns

### Observer Pattern

`HttpObserver` decouples HTTP client from logging mechanism.

### Ephemeral State

Marked `@doNotStore`. Architecture forbids disk persistence for security.

### Master-Detail Interface

`NetworkInspectorScreen` uses `LayoutBuilder` for responsive layout switching.

### Computed/Derived State

`HttpEventGroup` derived at runtime from flat event log; not stored.

### Safety Wrapper

Microtask scheduling prevents "setState called during build" errors when
HTTP requests trigger inside FutureBuilder or provider initialization.

## Cross-Component Dependencies

### Depends On

- **11 - Design System**: UI styling and tokens
- **12 - Shared Widgets**: Reusable UI components (AppShell, ShellConfig)
- **14 - HTTP Layer**: Network client types for logging display
- **17 - Utilities**: Data formatting utilities

### Used By

- **01 - App Shell**: Settings screen access to inspector
- **03 - State Core**: API provider logging HTTP traffic to the inspector
- **12 - Shared Widgets**: App shell embedding the inspector overlay
- **19 - Router**: Navigation routing entries

## Contribution Guidelines

### DO

- **Wrap State Updates in Microtasks:** When ingesting external events (like `HttpObserver`), always wrap `state = ...` in `scheduleMicrotask` to ensure thread safety relative to the Flutter build frame.
- **Derive Data in View Models:** Keep the `HttpLogNotifier` state simple (list of events). Use pure functions like `groupHttpEvents` or derived getters to compute UI representations.
- **Redact Sensitive Data Upstream:** Ensure the `ObservableHttpClient` cleans headers/bodies *before* passing them to `HttpLogNotifier`. The UI layer assumes data is safe to display.
- **Use `SelectableText`:** All log details (headers, bodies, cURL) must use `SelectableText` or `SelectionArea` to allow developers to copy debug information.
- **Limit State Size:** Respect the `maxEvents` cap (currently 500). Debug tools must not cause OOM crashes in long-running sessions.

### DON'T

- **No Persistence:** Never add persistence (Hive/SharedPrefs) to `httpLogProvider`. HTTP logs may contain session-specific tokens and must be ephemeral (memory only).
- **No Formatting in Build:** Avoid complex JSON pretty-printing in the `build()` method. Use utilities or memoize expensive string manipulations.
- **Don't Couple to Navigation:** Do not hardcode navigation logic inside `HttpEventTile`. Use callbacks (`onTap`) so the parent can decide between pushing a route or updating a selected ID.
- **Don't Block the UI Thread:** If log grouping becomes expensive (>1000 items), move `groupHttpEvents` to a `compute` isolate or optimize the sorting algorithm.
- **Respect the Ref Rule:** The `HttpLogNotifier` must remain pure Dart. It should not know about `BuildContext` or `ScaffoldMessenger`.

### Extending This Component

- **New Event Types:** If adding WebSocket or gRPC support, extend `HttpEvent` in the client package first, then update `groupHttpEvents` to handle the new correlation logic.
- **New Status Colors:** When adding status types, update `HttpStatusDisplay` and the `HTTPStatusColors` extension to ensure they adapt to both Light and Dark themes automatically.
- **Filter/Search:** Implement filtering by creating a derived Provider that uses `ref.watch(httpLogProvider)` and applies filters, rather than mutating the main log list.
