# iOS Patrol Setup & Constraints

## RunnerUITests target required

The iOS Xcode project needs a `RunnerUITests` UI test bundle target
(same pattern as macOS). The target, scheme entry, and Podfile entry
are already configured in this repo.

## Simulator OS version must match

Patrol uses `--ios=<version>` (defaults to `latest`). If the booted
simulator runs an older iOS than the latest installed SDK, pass the
version explicitly: `--ios=18.6`.

## Keyboard assertions

`ignoreKeyboardAssertions()` applies on iOS too (same Flutter bug as
macOS). No changes needed — the function works on both platforms.
