# Android Patrol Setup & Constraints

## Use Google APIs image, NOT Google Play

Android emulators created with a **Google Play** system image force a mandatory
Gmail login on first boot that cannot be skipped. Use **Google APIs** instead.

### One-time AVD setup (command line)

```bash
export ANDROID_HOME=~/Library/Android/sdk
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

# Download Google APIs image (non-Play Store)
sdkmanager "system-images;android-36;google_apis;arm64-v8a"

# Create AVD
avdmanager create avd \
  --name "Patrol_Test_API_36" \
  --package "system-images;android-36;google_apis;arm64-v8a" \
  --device "medium_phone"
```

**Or in Android Studio:** Device Manager > Create Device > select a system image
with target **"Google APIs"** (not "Google Play").

## localhost is 10.0.2.2

Android emulators cannot reach the host's `localhost` directly. Use
`10.0.2.2:8000` (maps to host `127.0.0.1:8000`) in `--dart-define`.

## ANDROID_HOME must be set

Patrol needs `ANDROID_HOME` and `adb` on PATH. Default macOS location:
`~/Library/Android/sdk`.

## JDK for sdkmanager/avdmanager

`sdkmanager` and `avdmanager` require JDK 17+. Android Studio bundles JDK 21
at `/Applications/Android Studio.app/Contents/jbr/Contents/Home`. Set
`JAVA_HOME` to this path before running SDK tools.

## Test orchestrator

The Gradle config uses `ANDROIDX_TEST_ORCHESTRATOR` with
`clearPackageData = true` for test isolation. This means each test run
gets a fresh app state.
