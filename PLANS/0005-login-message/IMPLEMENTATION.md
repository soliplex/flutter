# Implementation Plan: Configurable Login Message

## Overview

Two slices. Slice 1 adds the configurable login message (interstitial).
Slice 2 hardens the post-logout redirect path.

## Slice Summary

| # | Slice | ~Lines | Customer Value |
|---|-------|--------|----------------|
| 1 | Login message config + interstitial | ~120 | DoD consent banner before login |
| 2 | Post-logout redirect hardening | ~30 | Clean redirect after logout |

## Dependency Structure

```text
[1] Login message + interstitial
         │
         ▼
[2] Post-logout redirect hardening
```

Slice 2 is independent in code but logically follows slice 1 — after
adding the interstitial, we want logout to land back on it cleanly.

---

## Slice 1: Login Message Configuration + Interstitial

**Branch:** `feat/login-message`

**Target:** ~120 lines

**Customer value:** DoD deployments can configure a consent banner that
appears before login. Regular deployments are unaffected.

### Tasks

1. Create `lib/core/models/login_message.dart` — immutable model with
   `title`, `body`, `acknowledgmentLabel`
2. Add optional `loginMessage` field to `SoliplexConfig`
3. Modify `LoginScreen` to read `loginMessage` from config
4. When `loginMessage` is non-null and not yet acknowledged:
   - Show the message title, body (scrollable), and acknowledgment button
   - Hide the OIDC provider list
5. When acknowledged (or no message configured), show login options as today
6. Write tests (TDD)

### Files Created

- `lib/core/models/login_message.dart`
- `test/core/models/login_message_test.dart`
- `test/features/login/login_screen_test.dart` (or extend existing)

### Files Modified

- `lib/core/models/soliplex_config.dart` (add `loginMessage` field)
- `lib/features/login/login_screen.dart` (show interstitial)
- `test/core/models/soliplex_config_test.dart` (if exists, update)

### LoginMessage Model

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

### Login Screen Changes

```dart
class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isAuthenticating = false;
  String? _errorMessage;
  bool _messageAcknowledged = false;  // NEW

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(shellConfigProvider);
    final loginMessage = config.loginMessage;

    // If message configured and not acknowledged, show interstitial
    final showInterstitial =
        loginMessage != null && !_messageAcknowledged;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(SoliplexSpacing.s6),
            child: showInterstitial
                ? _buildInterstitial(loginMessage)
                : _buildLoginContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildInterstitial(LoginMessage message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message.title, style: ...headlineMedium, textAlign: center),
        const SizedBox(height: 24),
        Expanded(  // scrollable body for long DoD text
          child: SingleChildScrollView(
            child: Text(message.body, style: ...bodyMedium),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => setState(() => _messageAcknowledged = true),
          child: Text(message.acknowledgmentLabel),
        ),
      ],
    );
  }
}
```

### Tests (TDD)

1. **No message configured:** Login screen shows provider list immediately
   (existing behavior preserved).
2. **Message configured, not acknowledged:** Login screen shows message
   title, body, and acknowledgment button. Provider list is NOT visible.
3. **Message configured, acknowledged:** After tapping the acknowledgment
   button, provider list becomes visible. Message disappears.
4. **Custom acknowledgment label:** Button shows the configured label text.
5. **Default acknowledgment label:** Button shows "OK" when label not
   specified.
6. **LoginMessage equality and toString.**

### Acceptance Criteria

- [ ] `LoginMessage` model created with `title`, `body`,
      `acknowledgmentLabel`
- [ ] `SoliplexConfig.loginMessage` is optional (null by default)
- [ ] Login screen shows interstitial when configured
- [ ] Login options hidden until acknowledgment
- [ ] No change when `loginMessage` is null
- [ ] All tests pass (TDD)
- [ ] `dart format .` clean
- [ ] `flutter analyze --fatal-infos` reports 0 issues

---

## Slice 2: Post-Logout Redirect Hardening

**Branch:** `feat/login-message` (same branch, separate commit)

**Target:** ~30 lines

**Customer value:** After logout, users always land on the login screen
(with interstitial if configured), never on a confusing error page.

### Tasks

1. In `AuthCallbackScreen`, detect "empty callback" (no tokens, no error
   in URL) and redirect to `/login` instead of showing an error
2. Verify `WebAuthFlow.endSession` sets `post_logout_redirect_uri` correctly
3. Document KC configuration requirement for `post_logout_redirect_uri`
4. Write tests

### Context: Why This Matters

Issue #751 reports that after KC logout, users land on `/#/auth/callback`.
This happens when:

- KC's "Valid post logout redirect URIs" doesn't include the bare origin, so
  KC falls back to a registered redirect URI (the OAuth callback URL)
- A user bookmarks or manually navigates to `/auth/callback`

The current `WebAuthFlow.endSession` code is correct — it sets
`post_logout_redirect_uri: frontendOrigin`. But the `AuthCallbackScreen`
should handle the case where it loads without valid parameters gracefully.

### Files Modified

- `lib/features/auth/auth_callback_screen.dart` (handle empty callback)
- `test/features/auth/auth_callback_screen_test.dart` (add test)

### AuthCallbackScreen Change

```dart
// In the build method, when capturedParams has no tokens and no error:
// Instead of showing "Missing access token" error, redirect to /login.
if (capturedParams is NoCallbackParams) {
  // No OAuth callback in progress — redirect to login.
  // This handles: post-logout KC redirect, direct navigation, bookmarks.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) context.go('/login');
  });
  return const SizedBox.shrink();
}
```

### Tests

1. **AuthCallbackScreen with no params:** Redirects to `/login`.
2. **AuthCallbackScreen with valid tokens:** Completes auth (existing).
3. **AuthCallbackScreen with error:** Shows error (existing).

### KC Configuration Note

For web deployments, the Keycloak client must register the app's origin URL
in "Valid post logout redirect URIs":

```text
https://your-app-domain.com
```

Without this, KC ignores the `post_logout_redirect_uri` parameter and
redirects to a default URL (often the OAuth callback), causing the issue
described in #751.

### Acceptance Criteria

- [ ] `AuthCallbackScreen` redirects to `/login` when loaded without params
- [ ] Existing callback behavior (tokens, errors) unchanged
- [ ] Tests cover the empty-params case
- [ ] `dart format .` clean
- [ ] `flutter analyze --fatal-infos` reports 0 issues

---

## Critical Files

**Created:**

- `lib/core/models/login_message.dart` — Message model (slice 1)

**Modified:**

- `lib/core/models/soliplex_config.dart` — Add `loginMessage` field
  (slice 1)
- `lib/features/login/login_screen.dart` — Show interstitial (slice 1)
- `lib/features/auth/auth_callback_screen.dart` — Handle empty callback
  (slice 2)

## Definition of Done (per slice)

- [ ] All tasks completed
- [ ] All tests written and passing (TDD)
- [ ] Code formatted (`dart format .`)
- [ ] No analyzer issues (`flutter analyze --fatal-infos`)
- [ ] PR reviewed and approved
- [ ] Merged to main

## Open Questions

1. **Exact DoD banner text:** The Google Doc linked in #815 wasn't
   accessible. The shell app (appshell) will provide the exact text via
   `LoginMessage`. We provide the mechanism; they provide the content.

2. **Backend logout endpoint:** Issue #751 mentions a possible
   `/api/auth/{system}/logout` backend endpoint for backchannel logout.
   This is a backend concern — our frontend handles whatever redirect
   comes back. If the backend adds this endpoint, the frontend's
   `WebAuthFlow.endSession` could call it instead of redirecting to KC
   directly. This is out of scope for this plan.
