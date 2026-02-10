# Developer Setup Guide

Platform-specific setup instructions for building and running the Soliplex
Flutter frontend.

## Prerequisites

- Flutter SDK (stable channel)
- Xcode (for iOS/macOS)
- CocoaPods (`gem install cocoapods`)

## Quick Start

```bash
# Install dependencies
flutter pub get

# Install iOS/macOS pods
cd ios && pod install && cd ..
cd macos && pod install && cd ..

# Run the app
flutter run -d macos   # or: -d ios, -d chrome
```

## Platform Setup

### macOS

#### Code Signing (Required for Keychain)

macOS apps require code signing to access Keychain for secure token storage.
Each developer must configure their own Apple Developer Team ID:

```bash
# 1. Copy the template
cp macos/Runner/Configs/Local.xcconfig.template macos/Runner/Configs/Local.xcconfig

# 2. Edit Local.xcconfig and add your Team ID
```

Your `Local.xcconfig` should contain:

```text
DEVELOPMENT_TEAM = YOUR_TEAM_ID_HERE
```

Both iOS and macOS use Xcode's automatic signing, which selects the correct
identity based on build type (development vs release).

**Finding your Team ID:**

1. Go to <https://developer.apple.com/account>
2. Click "Membership details"
3. Copy the 10-character Team ID (e.g., `XXXXXXXXXX`)

**Verification:**

```bash
flutter build macos --debug
```

If configured correctly, Keychain operations succeed and auth tokens persist
across app restarts.

**Without code signing:** The app runs but Keychain fails silently. Auth works
per-session but tokens don't persist, requiring re-login on each launch.

### iOS

#### Code Signing (Required for Physical Devices)

iOS uses the same xcconfig pattern as macOS:

```bash
# 1. Copy the template
cp ios/Runner/Configs/Local.xcconfig.template ios/Runner/Configs/Local.xcconfig

# 2. Edit Local.xcconfig and add your Team ID
```

Your `Local.xcconfig` should contain:

```text
DEVELOPMENT_TEAM = YOUR_TEAM_ID_HERE
```

#### Simulator vs Device

- **Simulator:** No signing required for debug builds
- **Physical device:** Requires `Local.xcconfig` with valid `DEVELOPMENT_TEAM`

#### Building for TestFlight/App Store

**CRITICAL:** Use Flutter **stable** channel for production builds. Beta/dev
channels can produce binaries that fail App Store validation.

```bash
# Verify you're on stable channel
flutter channel stable
flutter upgrade

# Build release IPA
flutter build ipa --release

# Upload using Transporter app
open -a Transporter build/ios/ipa/soliplex_frontend.ipa

# Or use command line (requires API key)
xcrun altool --upload-app --type ios -f build/ios/ipa/soliplex_frontend.ipa \
  --apiKey YOUR_API_KEY --apiIssuer YOUR_ISSUER_ID
```

The `flutter build ipa --release` command automatically:

- Uses `Apple Distribution` signing identity
- Includes debug symbols (dSYM files)
- Creates properly encrypted binary for App Store submission

**Troubleshooting validation errors:** If you get "binary not built with Apple's
linker" errors, ensure you're on Flutter stable channel, not beta or dev.

### Web

No special setup required. Run with:

```bash
flutter run -d chrome
```

## Troubleshooting

### Entitlements require signing

```text
"Runner" has entitlements that require signing with a development certificate
```

**Cause:** Missing `Local.xcconfig` or `DEVELOPMENT_TEAM` not set.

**Fix:** Create `Local.xcconfig` with `DEVELOPMENT_TEAM` as shown above.

### Keychain errors on macOS

```text
OSStatus error -25293
```

**Cause:** Missing or invalid code signing configuration.

**Fix:** Follow the macOS code signing setup above.

### Pod install fails

```bash
# Clean and reinstall
cd ios && pod deintegrate && pod install && cd ..
cd macos && pod deintegrate && pod install && cd ..
```

### Flutter version issues

```bash
# Check version
flutter --version

# Upgrade if needed
flutter upgrade
```

## Related Files

| File | Purpose |
|------|---------|
| `macos/Runner/Configs/Local.xcconfig.template` | Template for macOS signing |
| `macos/Runner/Configs/Local.xcconfig` | Your macOS signing config (gitignored) |
| `ios/Runner/Configs/Local.xcconfig.template` | Template for iOS signing |
| `ios/Runner/Configs/Local.xcconfig` | Your iOS signing config (gitignored) |
| `.gitignore` | Excludes `**/Local.xcconfig` |
