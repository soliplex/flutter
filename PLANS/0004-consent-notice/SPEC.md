# Feature Specification: Configurable Login Message

## Overview

Add a configurable interstitial message to the login screen. Some deployments
require a consent-to-monitoring banner before system access; regular
deployments should not be affected.

## Problem Statement

Two problems exist today:

1. **No consent banner.** Regulated deployments require a "Notice and Consent"
   interstitial before users can access the system. There is no mechanism to
   show a message on the login screen.

2. **No configurability.** The interstitial must be opt-in — regular deployments
   don't want a consent banner. The message text varies by organization.

## Consent Banner Compliance Rules

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
- The verbatim consent banner text required by the deployment must be used.
  It cannot be summarized.
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
6. When no login message is configured, the login screen works exactly as it
   does today — no behavioral change.

### Non-Functional Requirements

- The login message configuration is compile-time (part of `SoliplexConfig`),
  not fetched from the backend. Shell apps define it in their `main.dart`.
- No new routes. The interstitial lives within the existing login screen.
- No new packages.

## Use Cases

### Use Case 1: Regulated Deployment — First Visit

1. Alice navigates to the deployment.
2. The login screen shows the consent banner with title, body text, and
   an "I Accept" button. The login form is not visible.
3. Alice reads the banner and taps "I Accept".
4. The login screen reveals the OIDC provider list.
5. Alice signs in normally.

### Use Case 2: Regulated Deployment — After Logout

1. Bob is signed in and clicks "Sign out".
2. The app clears tokens and redirects to the IdP logout endpoint.
3. Keycloak redirects back to the app origin.
4. The app loads, detects unauthenticated state, shows the login screen.
5. Bob sees the consent banner again (acknowledgment was session-scoped).

### Use Case 3: Regular Deployment — No Banner

1. Carol navigates to a regular deployment (no `consentNotice` in config).
2. The login screen shows the OIDC provider list immediately, with no
   interstitial.
3. Behavior is identical to today.

### Use Case 4: Deep Link Without Session

1. Eve bookmarks `/rooms/42` and closes the browser.
2. Eve opens the bookmark in a new session (no stored tokens).
3. Router detects unauthenticated state, redirects to `/login`.
4. Login screen shows the consent banner (interstitial).
5. Eve acknowledges, signs in, and lands on the authenticated landing
   route (not `/rooms/42` — deep link preservation is not implemented).

### Use Case 5: Session Timeout

1. Frank's session expires while on `/rooms/42`.
2. Token refresh fails, auth state becomes `Unauthenticated(sessionExpired)`.
3. Router redirects to `/login`.
4. Login screen rebuilds with fresh widget state — interstitial reappears.
5. Frank acknowledges the banner and signs in again.

## Acceptance Criteria

- [ ] `ConsentNotice` model exists with `title`, `body`, `acknowledgmentLabel`
- [ ] `SoliplexConfig` accepts an optional `consentNotice`
- [ ] Login screen shows blocking interstitial when `consentNotice` is configured
- [ ] Login form is hidden until user clicks acknowledgment button
- [ ] Acknowledgment resets on logout / session timeout (session-scoped)
- [ ] Deep links without session redirect to banner via `/login`
- [ ] No behavioral change when `consentNotice` is null (default)
- [ ] All existing tests pass
- [ ] New tests cover interstitial display, acknowledgment, and hide behavior
