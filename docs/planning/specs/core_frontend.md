# Core Frontend

*Last updated: January 2026*

Flutter infrastructure using the `soliplex_client` package for backend interactions.

## Responsibilities

- Authentication (login/logout via OIDC)
- Backend URL configuration
- Navigation (go_router)
- State management (Riverpod)
- AG-UI event processing
- Extensibility (config, registries)

## Platforms

Web (primary), iOS, Android, macOS, Windows, Linux

## Key Providers

| Provider | Type | Purpose |
|----------|------|---------|
| `configProvider` | StateProvider | App configuration (baseUrl) |
| `apiProvider` | Provider | SoliplexApi instance with HTTP transport |
| `authNotifierProvider` | NotifierProvider | Auth state management (OIDC) |
| `roomsProvider` | FutureProvider | Room list from backend |
| `threadsProvider` | FutureProvider.family | Thread list for room |
| `activeRunNotifierProvider` | NotifierProvider | AG-UI run state (sealed class) |
| `threadMessageCacheProvider` | NotifierProvider | Message cache per thread |
| `httpLogProvider` | StateProvider | HTTP traffic logging for inspector |
| `backendHealthProvider` | FutureProvider | Backend availability check |
| `packageInfoProvider` | FutureProvider | App version and build info |

## ActiveRunState

A sealed class hierarchy for type-safe exhaustive pattern matching:

```dart
sealed class ActiveRunState {
  Conversation get conversation;
  StreamingState get streaming;
  List<ChatMessage> get messages;
  List<ToolCallInfo> get activeToolCalls;
  bool get isRunning;
}

class IdleState extends ActiveRunState { }      // No active run (sentinel)
class RunningState extends ActiveRunState {     // Run is executing
  final Conversation conversation;
  final StreamingState streaming;
  String get threadId;
  String get runId;
  bool get isStreaming;
}
class CompletedState extends ActiveRunState {   // Run finished
  final Conversation conversation;
  final CompletionResult result;                // Success | FailedResult | CancelledResult
}

sealed class CompletionResult { }
class Success extends CompletionResult { }
class FailedResult extends CompletionResult { final String errorMessage; }
class CancelledResult extends CompletionResult { final String reason; }
```

Usage with pattern matching:

```dart
switch (state) {
  case IdleState():
    // No active run
  case RunningState(:final threadId, :final streaming):
    // Run is active
  case CompletedState(:final result):
    switch (result) {
      case Success(): // Completed successfully
      case FailedResult(:final errorMessage): // Failed
      case CancelledResult(:final reason): // Cancelled
    }
}
```

## Authentication Flow

1. Open webview to `{baseUrl}/api/login/{provider}`
2. Server handles OIDC flow
3. Callback returns token
4. Store token securely

## Routes

| Route | Screen | Description |
|-------|--------|-------------|
| `/` | HomeScreen | Backend URL configuration |
| `/login` | LoginScreen | OIDC provider selection |
| `/auth/callback` | AuthCallbackScreen | OAuth callback handler |
| `/rooms` | RoomsScreen | Room list |
| `/rooms/:roomId` | RoomScreen | Room view with thread selection |
| `/rooms/:roomId/thread/:threadId` | (redirect) | Redirects to `/rooms/:roomId?thread=:threadId` |
| `/settings` | SettingsScreen | App configuration and auth status |

## AG-UI Event Handling

| Event | Action |
|-------|--------|
| `RUN_STARTED` | status = running |
| `TEXT_MESSAGE_*` | Update messages |
| `TOOL_CALL_*` | Update activity |
| `STATE_SNAPSHOT/DELTA` | Update stateItems |
| `RUN_FINISHED/ERROR` | status = finished/error |

## Error Handling

| Exception | Action |
|-----------|--------|
| `AuthException` | Redirect to login |
| `NetworkException` | Show retry |
| `NotFoundException` | Go back |
| `ApiException` | Show error |

## Extensibility (Level 2)

### SoliplexConfig

Configuration-driven customization at startup.

| Field | Purpose |
|-------|---------|
| `appName` | Display name |
| `theme` | ThemeData override |
| `features` | Enable/disable panels |
| `routes` | Initial route, hidden routes |
| `defaultServers` | Pre-configured backends |

### SoliplexRegistry

Runtime extension registration.

| Registry | Extensions |
|----------|------------|
| `widgets` | Custom GenUI widget builders |
| `commands` | Custom slash commands |
| `panels` | Custom panel definitions |
| `routes` | Custom route definitions |

### Key Abstractions

```dart
class SlashCommand {
  final String name;
  final String description;
  final bool Function(List<String> args, RoomSession session) handler;
}

class PanelDefinition {
  final String id;
  final String name;
  final IconData icon;
  final Widget Function(BuildContext, WidgetRef) builder;
  final PanelPosition defaultPosition;
}

class RouteDefinition {
  final String path;
  final Widget Function(BuildContext, GoRouterState) builder;
}
```

## Implementation Phases

| Phase | Goal | Milestone | Status |
|-------|------|-----------|--------|
| 1 | Project setup, navigation (NO AUTH) | AM1 | ✅ Done |
| 2 | ActiveRunNotifier + extensions | AM3 | ✅ Done |
| 3 | Authentication (OIDC, platform-specific flows) | AM7 | ✅ Done |
| 4 | Multi-room, extract to `soliplex_core` package | AM8 | Pending |

## Dependencies

```yaml
dependencies:
  soliplex_client:
    path: packages/soliplex_client
  soliplex_client_native:
    path: packages/soliplex_client_native
  flutter_riverpod: ^3.1.0
  go_router: ^17.0.0
  flutter_secure_storage: ^10.0.0
  flutter_appauth: ^11.0.0           # OIDC flows
  shared_preferences: ^2.5.4         # Config persistence
  package_info_plus: ^9.0.0          # App version info
  http: ^1.2.0
  flutter_markdown: ^0.7.4+1         # Message rendering
  flutter_highlight: ^0.7.0          # Code highlighting

dev_dependencies:
  very_good_analysis: ^10.0.0
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
```

**Linting:** Use `very_good_analysis`. Run `flutter analyze` and `dart format .` before commits.
