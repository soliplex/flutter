# 19 - Navigation & Routing

## Overview

Application routing using GoRouter with declarative route definitions, auth guards,
and deep linking support. Integrates with auth state for protected routes.

## Files

| File | Purpose |
|------|---------|
| `lib/core/router/app_router.dart` | Route configuration |

## Public API

### Router Configuration

**`appRouter(WidgetRef)`** - Creates configured GoRouter instance

**Routes:**

- `/` - Home (backend URL entry)
- `/login` - Login screen
- `/auth/callback` - OAuth callback handler
- `/rooms` - Room listing
- `/rooms/:roomId` - Room detail with optional `?thread=` query
- `/rooms/:roomId/quiz/:quizId` - Quiz screen
- `/settings` - Settings
- `/settings/network` - HTTP inspector
- `/settings/backend-versions` - Version info

### Guards

- **Auth Guard** - Redirects unauthenticated users to login
- **No-Auth Guard** - Redirects authenticated users away from login

## Dependencies

### External Packages

- `go_router` - Declarative routing
- `flutter_riverpod` - Auth state access

### Internal Dependencies

| Domain | Imports |
|--------|---------|
| Core/Auth | `authProvider`, `hasAppAccessProvider` |
| Core/Providers | `shellConfigProvider` (for route config) |
| Features | All screen widgets |

## Route Resolution Flow

```text
1. User navigates to path
2. GoRouter matches route
3. Guard checks auth state:
   ├─ Protected route + unauthenticated → /login
   ├─ Login route + authenticated → authenticatedLandingRoute
   └─ Pass → Render screen
4. Parameters extracted (roomId, threadId, quizId)
5. Screen widget instantiated with params
```

## Architectural Patterns

### Declarative Routing

Routes defined as configuration, not imperative navigation.

### Auth State Integration

Router watches `authStatusListenableProvider` for auth changes.

### Deep Linking

Query parameters (`?thread=`) and path parameters (`:roomId`) support
direct navigation to specific content.

### Route Guards

Redirect logic centralized in router rather than scattered in screens.

## Cross-Component Dependencies

### Depends On

- **01 - App Shell**: Navigation targets (Home, Settings screens)
- **02 - Authentication**: Auth guards and Login screens
- **06 - Rooms**: Navigation targets (Room lists/details)
- **09 - Inspector**: Navigation target (Inspector tools)
- **10 - Configuration**: Router configuration and feature flags
- **12 - Shared Widgets**: UI helpers for navigation
- **20 - Quiz**: Navigation target (Quiz features)

### Used By

- **01 - App Shell**: Initializes the application router

## Contribution Guidelines

### DO

- **Use Feature Flags for Route Definition:** Wrap `GoRoute` definitions in `if (features.enableFeature)` checks to dynamically enable/disable entire route branches based on `shellConfigProvider`.
- **Centralize Redirect Logic:** Place all authentication and permission-based access control inside the `redirect` callback. Use `ref.read` (not watch) within the redirect function.
- **Use `NoTransitionPage`:** Default to `NoTransitionPage` for standard screen transitions to mimic a web-application feel, unless a specific animation is required.
- **Watch `authStatusListenableProvider`:** Pass the auth notifier to `refreshListenable`. This ensures the router reacts to Login/Logout events but avoids rebuilding on minor state changes.
- **Normalize Paths:** Use path normalization helpers in redirects to handle trailing slashes consistently, preventing infinite redirect loops.

### DON'T

- **No Side Effects in Redirects:** The `redirect` function must be pure logic returning a `String?`. Do not trigger API calls or state mutations here.
- **Don't Bypass the Ref Rule:** Do not pass `WidgetRef` to helper functions outside the build method. The router provider itself has access to `Ref` and should use it.
- **Don't Duplicate Guard Logic:** Do not check `authProvider` in individual screen widgets to decide if a user can view them. Rely on the router's `redirect` logic.
- **No Hardcoded Deeply Nested Paths:** Avoid manually constructing strings like `'/rooms/$id/quiz/$qid'`. Use `pathParameters` in `GoRouter` and build URLs using named route location helpers.
- **Don't Couple Screens to Router Implementation:** Screens should receive parameters via constructor, parsed in the `pageBuilder`. Do not access `GoRouterState` inside the screen widget.

### Extending This Component

- **New Routes:** Add new `GoRoute` entries to the `routes` list. Ensure they are wrapped in `_staticPage` if they require the standard application shell.
- **Deep Links:** Use query parameters (e.g., `?thread=`) for optional state deep-linking rather than creating separate route definitions.
- **New Guards:** Add logic to the `redirect` function. If a new provider is needed for the guard, read it via `ref.read` inside the redirect block.
