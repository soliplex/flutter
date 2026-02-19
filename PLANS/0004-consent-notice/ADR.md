# ADR: Configurable Login Message

## Status

Accepted

## Context

Regulated deployments require a consent-to-monitoring banner before system
access. This must be configurable — deployments that don't require a consent
banner should not see it.

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

## Decision

### 1. ConsentNotice as a Configuration Model

Add `ConsentNotice` to `SoliplexConfig`:

```dart
@immutable
class ConsentNotice {
  const ConsentNotice({
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
    this.consentNotice,
  });

  final ConsentNotice? consentNotice;
}
```

**Rationale:** Compile-time configuration via `SoliplexConfig` matches the
existing pattern for white-label customization (app name, features, routes,
theme). The message varies by deployment, not by runtime state.

**Why nullable:** The default is "no message". `null` means no interstitial.
This is simpler than a boolean flag plus message fields, and eliminates the
invalid state of `showBanner: true` with empty message text.

**Why `body` is a String rendered as markdown:** The body is rendered via
`FlutterMarkdownPlusRenderer` in a scrollable view. This allows shell apps
to use markdown formatting (headings, lists, emphasis) for readability while
still supporting plain prose verbatim. Plain text passes through unchanged.

### 2. Interstitial Within the Login Screen (Not a Separate Route)

The message is shown as a state within the existing `LoginScreen` widget.
Before acknowledgment, the login options are hidden. After acknowledgment,
they appear.

```text
┌─────────────────────────────────────┐
│          Login Screen               │
│                                     │
│  consentNotice == null?              │
│    ├─ YES → show login options      │
│    └─ NO → show interstitial        │
│             ├─ consentGiven?        │
│             │  ├─ YES → show login  │
│             │  └─ NO → show message │
│             └───────────────────────│
└─────────────────────────────────────┘
```

**Rationale:**

- **No new routes.** Adding a `/consent` route would require router changes,
  redirect logic, and a new public route entry. The interstitial is part of
  the login flow, not a navigation destination.
- **Simple state.** A single `_consentGiven` boolean in `_LoginScreenState`
  controls visibility. Resets automatically when the widget rebuilds (logout
  recreates the route, resetting state).
- **Session-scoped by default.** Widget state is ephemeral — destroyed on
  logout/navigation. No persistence needed.

**Compliance via existing router architecture:**

The compliance rules require the banner before deep links and after session
timeout. Both are already handled by the router's auth guard:

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
satisfies all banner display rules.

**Alternative considered:** Separate `/consent` route.
Rejected because it adds routing complexity for a UI-only concern. The
interstitial is not a destination users navigate to — it's a gate before
login. The existing router already ensures all unauthenticated access flows
through `/login`.

### 3. Acknowledgment Is Widget State (Not Provider State)

The `_consentGiven` flag lives in `_LoginScreenState`, not in a Riverpod
provider.

**Rationale:**

- Session-scoping is free: widget state resets on rebuild.
- No persistence needed (compliance requires re-acknowledgment every session).
- No cross-widget communication needed (only the login screen cares).
- YAGNI: a provider would be needed if other screens checked acknowledgment
  status. They don't.

## Consequences

### Positive

- Zero impact on deployments without `consentNotice` configured
- Follows existing `SoliplexConfig` pattern — no new mechanism to learn
- Minimal code change (one new model, login screen modification)
- Session-scoped acknowledgment is automatic (widget lifecycle)
- No new routes, providers, or dependencies

### Negative

- If multiple screens ever need to check acknowledgment, we'd need to
  promote to a provider (unlikely — acknowledgment is a login concern)

### Risks

- **Banner text accuracy:** The exact required text varies by organization.
  We provide the mechanism; the shell app provides the text.
