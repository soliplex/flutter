# ADR: Configurable Login Message

## Status

Proposed

## Context

DoD deployments require a consent-to-monitoring banner before system access
([#751](https://github.com/enfold/afsoc-rag/issues/751),
[#815](https://github.com/enfold/afsoc-rag/issues/815)). This must be
configurable — non-DoD deployments should not see it.

See [SPEC.md](./SPEC.md) for requirements and use cases.

### Current Architecture

The login screen (`LoginScreen`) is a chrome-less `Scaffold` that shows the
app name, "Sign in to continue", and a list of OIDC providers. There is no
mechanism for pre-login messaging.

```dart
// login_screen.dart — current structure
Scaffold(
  body: Center(
    child: Column(
      children: [
        Text(appName),           // App name
        Text('Sign in to...'),   // Subtitle
        issuersAsync.when(...),  // Provider buttons
      ],
    ),
  ),
)
```

Post-logout on web, `WebAuthFlow.endSession` sets
`post_logout_redirect_uri: frontendOrigin`. After KC redirects, the app
reloads and the router sends unauthenticated users to `/login` or `/`.
However, issue #751 reports users landing on `/#/auth/callback` — this
happens when KC's `post_logout_redirect_uri` isn't properly registered, or
when an older code path used the callback URL as the redirect target.

## Decision

### 1. LoginMessage as a Configuration Model

Add `LoginMessage` to `SoliplexConfig`:

```dart
@immutable
class LoginMessage {
  const LoginMessage({
    required this.title,
    required this.body,
    this.acknowledgmentLabel = 'OK',
  });

  final String title;
  final String body;
  final String acknowledgmentLabel;
}
```

```dart
class SoliplexConfig {
  const SoliplexConfig({
    // ...existing fields...
    this.loginMessage,
  });

  final LoginMessage? loginMessage;
}
```

**Rationale:** Compile-time configuration via `SoliplexConfig` matches the
existing pattern for white-label customization (app name, features, routes,
theme). The message varies by deployment, not by runtime state.

**Why nullable:** The default is "no message". `null` means no interstitial.
This is simpler than a boolean flag plus message fields, and eliminates the
invalid state of `showBanner: true` with empty message text.

**Why `body` is a plain String:** DoD requires verbatim use of the Standard
Mandatory Notice and Consent Banner text (~1,300 chars). The body is rendered
in a scrollable view. No markdown or rich text needed — the official text is
plain prose. Shell apps pass the exact required text.

### 2. Interstitial Within the Login Screen (Not a Separate Route)

The message is shown as a state within the existing `LoginScreen` widget.
Before acknowledgment, the login options are hidden. After acknowledgment,
they appear.

```text
┌─────────────────────────────────────┐
│          Login Screen               │
│                                     │
│  loginMessage == null?              │
│    ├─ YES → show login options      │
│    └─ NO → show interstitial        │
│             ├─ acknowledged?        │
│             │  ├─ YES → show login  │
│             │  └─ NO → show message │
│             └───────────────────────│
└─────────────────────────────────────┘
```

**Rationale:**

- **No new routes.** Adding a `/consent` route would require router changes,
  redirect logic, and a new public route entry. The interstitial is part of
  the login flow, not a navigation destination.
- **Simple state.** A single `_acknowledged` boolean in `_LoginScreenState`
  controls visibility. Resets automatically when the widget rebuilds (logout
  recreates the route, resetting state).
- **Session-scoped by default.** Widget state is ephemeral — destroyed on
  logout/navigation. No persistence needed.

**DoD compliance via existing router architecture:**

The DoD rules require the banner before deep links and after session timeout.
Both are already handled by the router's auth guard:

- **Deep link (no session):** User opens `/rooms/42` → router detects
  `!hasAccess && !isPublicRoute` → redirects to `/login` → interstitial
  shows (fresh widget state).
- **Session timeout:** Token refresh fails → `Unauthenticated` state →
  router redirects to `/login` → interstitial shows.
- **Logout:** `Unauthenticated(explicitSignOut)` → router redirects to
  `/login` (or `/` then `/login`) → interstitial shows.
- **Active session navigation:** Authenticated users never see `/login` →
  banner never re-shows during a session.

No router changes needed. The existing auth guard + login screen interstitial
satisfies all DoD banner display rules.

**Alternative considered:** Separate `/consent` route.
Rejected because it adds routing complexity for a UI-only concern. The
interstitial is not a destination users navigate to — it's a gate before
login. The existing router already ensures all unauthenticated access flows
through `/login`.

### 3. Post-Logout Redirect Fix

The current `WebAuthFlow.endSession` sets:

```dart
'post_logout_redirect_uri': frontendOrigin,
```

This redirects to the bare origin (e.g., `http://localhost:59001`), which
then loads the app, detects unauthenticated state, and the router sends the
user to `/login`.

The issue (#751) reports KC redirecting to `/#/auth/callback`. Investigation
shows this is because `post_logout_redirect_uri` was set to the callback URL
in an older version of the code. The current code is correct but we need to
ensure:

1. The `post_logout_redirect_uri` sent to KC matches a URI registered in the
   KC client's "Valid post logout redirect URIs" setting.
2. On web with hash routing, the bare origin loads the app at `/` which the
   router redirects to `/login`.

**No code change needed** for the redirect itself — the current implementation
is correct. The fix is a KC configuration concern (documented in the
implementation plan).

However, we should add a **defensive improvement**: if the app loads at
`/auth/callback` without valid token parameters, the `AuthCallbackScreen`
should redirect to `/login` instead of showing an error. This handles the
case where KC is misconfigured or the user bookmarks the callback URL.

### 4. Acknowledgment Is Widget State (Not Provider State)

The `_acknowledged` flag lives in `_LoginScreenState`, not in a Riverpod
provider.

**Rationale:**

- Session-scoping is free: widget state resets on rebuild.
- No persistence needed (DoD requires re-acknowledgment every session).
- No cross-widget communication needed (only the login screen cares).
- YAGNI: a provider would be needed if other screens checked acknowledgment
  status. They don't.

## Consequences

### Positive

- Zero impact on deployments without `loginMessage` configured
- Follows existing `SoliplexConfig` pattern — no new mechanism to learn
- Minimal code change (one new model, login screen modification)
- Session-scoped acknowledgment is automatic (widget lifecycle)
- No new routes, providers, or dependencies

### Negative

- If multiple screens ever need to check acknowledgment, we'd need to
  promote to a provider (unlikely — acknowledgment is a login concern)

### Risks

- **KC configuration:** The post-logout redirect depends on KC having the
  correct `post_logout_redirect_uri` registered. This is a deployment
  concern, not a code concern. Documented in implementation plan.
- **DoD banner text accuracy:** The exact required text varies by
  organization. We provide the mechanism; the shell app provides the text.
