# Feature Specification: Configurable Login Message

## Overview

Add a configurable interstitial message to the login screen and fix
post-logout redirect behavior. DoD deployments require a consent-to-monitoring
banner before system access; regular deployments should not be affected.

## Problem Statement

**Issues:** [#751](https://github.com/enfold/afsoc-rag/issues/751),
[#815](https://github.com/enfold/afsoc-rag/issues/815)

Three problems exist today:

1. **No consent banner.** DoD requires a "Notice and Consent" interstitial
   before users can access the system. There is no mechanism to show a message
   on the login screen.

2. **No configurability.** The interstitial must be opt-in — regular deployments
   don't want a DoD banner. The message text varies by organization.

3. **Post-logout redirect lands on `/auth/callback`.** After Keycloak logout,
   the browser redirects to `/#/auth/callback` (the OAuth return URL) instead
   of the login screen. This shows a confusing "missing token" error.

## DoD Banner Compliance Rules

Source: [DoD Banner Rules](https://docs.google.com/document/d/14cl3wVZIUeOWav4LBdCSrMYXBuETUYcmW8BpbpRcZfc)
(DoDI 8500.01, DISA STIGs)

| Scenario | Banner Required? | Click-Through? | Notes |
|----------|-----------------|----------------|-------|
| Initial login | YES | YES | Must block login form until accepted |
| Logout & log back in | YES | YES | Fresh entry — banner reappears |
| Session timeout | YES | YES | Redirect to login triggers banner |
| Page navigation (active session) | NO | NO | Don't re-show during session |
| Deep link (no session) | YES | YES | Redirect to banner before deep link |

**Key rules:**

- The banner is a legal "Notice and Consent" mechanism that removes the user's
  expectation of privacy. It must display **before** the login form.
- A positive action ("I Agree" / "OK") is required. The login form must not
  appear until the button is pressed.
- The verbatim Standard Mandatory DoD Notice and Consent Banner text
  (~1,300 chars) must be used. It cannot be summarized.
- If a user deep-links to an internal page without a session, the system must
  redirect to the banner first.

## Requirements

### Functional Requirements

1. Shell apps can configure an optional login message via `SoliplexConfig`.
2. When configured, the login screen shows the message as a **blocking
   interstitial** — the login form is hidden until the user clicks the
   acknowledgment button.
3. The message includes a configurable title, body, and button label.
4. Acknowledgment is session-scoped: the banner reappears after every logout,
   session timeout, app restart, or browser refresh.
5. Deep links to protected routes without a session redirect through the
   banner (already handled by router → `/login` redirect).
6. After OIDC logout on web, the user lands on the login screen (with the
   interstitial if configured), not on `/auth/callback`.
7. When no login message is configured, the login screen works exactly as it
   does today — no behavioral change.

### Non-Functional Requirements

- The login message configuration is compile-time (part of `SoliplexConfig`),
  not fetched from the backend. Shell apps define it in their `main.dart`.
- No new routes. The interstitial lives within the existing login screen.
- No new packages.

## Use Cases

### Use Case 1: DoD Deployment — First Visit

1. Alice navigates to the Soliplex deployment.
2. The login screen shows the DoD consent banner with title, body text, and
   an "I Accept" button. The login form is not visible.
3. Alice reads the banner and taps "I Accept".
4. The login screen reveals the OIDC provider list.
5. Alice signs in normally.

### Use Case 2: DoD Deployment — After Logout

1. Bob is signed in and clicks "Sign out".
2. The app clears tokens and redirects to the IdP logout endpoint.
3. Keycloak redirects back to the app origin.
4. The app loads, detects unauthenticated state, shows the login screen.
5. Bob sees the DoD consent banner again (acknowledgment was session-scoped).

### Use Case 3: Regular Deployment — No Banner

1. Carol navigates to a regular Soliplex deployment (no `loginMessage` in
   config).
2. The login screen shows the OIDC provider list immediately, with no
   interstitial.
3. Behavior is identical to today.

### Use Case 4: Web Logout — Clean Redirect

1. Dave is on web, clicks "Sign out".
2. App clears tokens, sets `Unauthenticated(explicitSignOut)`.
3. Web auth flow redirects to KC's `end_session_endpoint` with
   `post_logout_redirect_uri` set to the app's origin.
4. KC redirects Dave back to the app.
5. Dave sees the login screen (not `/auth/callback`).

### Use Case 5: Deep Link Without Session

1. Eve bookmarks `/rooms/42` and closes the browser.
2. Eve opens the bookmark in a new session (no stored tokens).
3. Router detects unauthenticated state, redirects to `/login`.
4. Login screen shows the DoD consent banner (interstitial).
5. Eve acknowledges, signs in, and lands on the authenticated landing route.

### Use Case 6: Session Timeout

1. Frank's session expires while on `/rooms/42`.
2. Token refresh fails, auth state becomes `Unauthenticated(sessionExpired)`.
3. Router redirects to `/login`.
4. Login screen rebuilds with fresh widget state — interstitial reappears.
5. Frank acknowledges the banner and signs in again.

## Acceptance Criteria

- [ ] `LoginMessage` model exists with `title`, `body`, `acknowledgmentLabel`
- [ ] `SoliplexConfig` accepts an optional `loginMessage`
- [ ] Login screen shows blocking interstitial when `loginMessage` is configured
- [ ] Login form is hidden until user clicks acknowledgment button
- [ ] Acknowledgment resets on logout / session timeout (session-scoped)
- [ ] Deep links without session redirect to banner via `/login`
- [ ] Post-logout redirect lands on login screen on web
- [ ] No behavioral change when `loginMessage` is null (default)
- [ ] All existing tests pass
- [ ] New tests cover interstitial display, acknowledgment, and hide behavior
