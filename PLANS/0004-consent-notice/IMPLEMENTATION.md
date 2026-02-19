# Implementation Plan: Configurable Login Message

## Overview

Single slice. Adds a configurable login message (interstitial) to the login
screen.

## Slice Summary

| # | Slice | ~Lines | Customer Value |
|---|-------|--------|----------------|
| 1 | Login message config + interstitial | ~120 | Consent banner before login |

---

## Slice 1: Login Message Configuration + Interstitial

**Branch:** `feat/login-message`

**Target:** ~120 lines

**Customer value:** Regulated deployments can configure a consent banner that
appears before login. Regular deployments are unaffected.

### Tasks

1. Create `lib/core/models/consent_notice.dart` — immutable model with
   `title`, `body`, `acknowledgmentLabel`
2. Add optional `consentNotice` field to `SoliplexConfig`
3. Modify `LoginScreen` to read `consentNotice` from config
4. When `consentNotice` is non-null and not yet acknowledged:
   - Show the message title, body (scrollable), and acknowledgment button
   - Hide the OIDC provider list
5. When acknowledged (or no message configured), show login options as today
6. Write tests (TDD)

### Files Created

- `lib/core/models/consent_notice.dart`
- `test/core/models/consent_notice_test.dart`
- `test/features/login/login_screen_test.dart` (or extend existing)

### Files Modified

- `lib/core/models/soliplex_config.dart` (add `consentNotice` field)
- `lib/features/login/login_screen.dart` (show interstitial)
- `test/core/models/soliplex_config_test.dart` (if exists, update)

### ConsentNotice Model

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

### Login Screen Changes

```dart
class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isAuthenticating = false;
  String? _errorMessage;
  bool _messageAcknowledged = false;  // NEW

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(shellConfigProvider);
    final consentNotice = config.consentNotice;

    // If message configured and not acknowledged, show interstitial
    final showInterstitial =
        consentNotice != null && !_messageAcknowledged;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(SoliplexSpacing.s6),
            child: showInterstitial
                ? _buildInterstitial(consentNotice)
                : _buildLoginContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildInterstitial(ConsentNotice message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message.title, style: ...headlineMedium, textAlign: center),
        const SizedBox(height: 24),
        Expanded(  // scrollable body for long consent text
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
6. **ConsentNotice equality and toString.**

### Acceptance Criteria

- [ ] `ConsentNotice` model created with `title`, `body`,
      `acknowledgmentLabel`
- [ ] `SoliplexConfig.consentNotice` is optional (null by default)
- [ ] Login screen shows interstitial when configured
- [ ] Login options hidden until acknowledgment
- [ ] No change when `consentNotice` is null
- [ ] All tests pass (TDD)
- [ ] `dart format .` clean
- [ ] `flutter analyze --fatal-infos` reports 0 issues

---

## Critical Files

**Created:**

- `lib/core/models/consent_notice.dart` — Message model

**Modified:**

- `lib/core/models/soliplex_config.dart` — Add `consentNotice` field
- `lib/features/login/login_screen.dart` — Show interstitial

## Definition of Done

- [ ] All tasks completed
- [ ] All tests written and passing (TDD)
- [ ] Code formatted (`dart format .`)
- [ ] No analyzer issues (`flutter analyze --fatal-infos`)
- [ ] PR reviewed and approved
- [ ] Merged to main

## Open Questions

1. **Exact banner text:** The shell app will provide the exact required text
   via `ConsentNotice`. We provide the mechanism; they provide the content.
