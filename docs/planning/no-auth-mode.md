# No-Auth Mode Support

## Problem

When backend runs with `--no-auth-mode`, the Flutter app got stuck on login
screen showing "No identity providers configured" with no way to proceed.

## Solution

Added `NoAuthRequired` as a new `AuthState` variant. Router treats it like
`Authenticated` for access control, but no token is sent to the backend.

## Key Changes

- `AuthState` - Added `NoAuthRequired` sealed class variant
- `AuthNotifier` - Added `enterNoAuthMode()` and `exitNoAuthMode()` methods
- `hasAppAccessProvider` - Renamed from `isAuthenticatedProvider`; returns true
  for both `Authenticated` and `NoAuthRequired`
- `HomeScreen._connect()` - Detects empty providers list and calls
  `enterNoAuthMode()`; handles backend switching with URL normalization

## Design Decisions

1. **Explicit state over nullable auth** - `NoAuthRequired` is clearer than
   null/empty checks scattered throughout the codebase
2. **No persistence** - Re-detect on each connect to handle backend config
   changes
3. **Guard on exitNoAuthMode()** - Throws `StateError` if called from
   `Authenticated` to prevent accidentally skipping token cleanup
4. **URL normalization** - Trailing slash differences don't trigger unnecessary
   auth state resets
