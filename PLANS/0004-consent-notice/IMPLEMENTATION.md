# Implementation Plan: Configurable Login Message

## Overview

Two slices. Adds a configurable login message (interstitial) to the login
screen.

## Slice Summary

| # | Slice | Branch | ~Lines | Customer Value |
|---|-------|--------|--------|----------------|
| 0 | ConsentNotice model + basic interstitial | `feat/display-consent-form-slice-1` | ~120 | Consent banner before login |
| 1 | Responsive layout + markdown body | `feat/display-consent-form-slice-1` | ~30 | Readable on all viewports; rich text support |

---

## Slice 0: ConsentNotice Model + Basic Interstitial

**Status:** Complete (merged into slice 1 branch)

## Slice 1: Responsive Layout + Markdown Body

**Branch:** `feat/display-consent-form-slice-1`

**Target:** ~150 lines total

**Customer value:** Regulated deployments can configure a consent banner that
appears before login. Regular deployments are unaffected.

### Tasks

1. Create `lib/core/models/consent_notice.dart` — immutable model with
   `title`, `body`, `acknowledgmentLabel`
2. Add optional `consentNotice` field to `SoliplexConfig`
3. Modify `LoginScreen` to read `consentNotice` from config
4. When `consentNotice` is non-null and not yet acknowledged:
   - Show the message title, body (scrollable markdown), and acknowledgment
     button
   - Hide the OIDC provider list
5. Responsive layout: 2/3 width on desktop, full width (minus padding) on
   mobile via `LayoutBuilder` + `SoliplexBreakpoints`
6. Render body as markdown via `FlutterMarkdownPlusRenderer`
7. When acknowledged (or no message configured), show login options as today
8. Write tests (TDD)

### Files Created

- `lib/core/models/consent_notice.dart`
- `test/core/models/consent_notice_test.dart`
- `test/features/login/login_screen_test.dart` (or extend existing)

### Files Modified

- `lib/core/models/soliplex_config.dart` (add `consentNotice` field)
- `lib/features/login/login_screen.dart` (show interstitial with responsive
  layout and markdown body)
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
  bool _consentGiven = false;
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(shellConfigProvider);
    final consentNotice = config.consentNotice;

    if (consentNotice != null && !_consentGiven) {
      return Scaffold(body: _buildInterstitial(consentNotice));
    }
    // ... existing login UI ...
  }

  Widget _buildInterstitial(ConsentNotice notice) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxContentWidth = width >= SoliplexBreakpoints.desktop
            ? width * 2 / 3
            : width - SoliplexSpacing.s4 * 2;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.all(SoliplexSpacing.s6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(notice.title, style: ...headlineLarge, textAlign: center),
                  const SizedBox(height: 48),
                  Flexible(
                    child: SingleChildScrollView(
                      child: FlutterMarkdownPlusRenderer(data: notice.body),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: FilledButton(
                        onPressed: () => setState(() => _consentGiven = true),
                        child: Padding(
                          padding: const EdgeInsetsGeometry.all(SoliplexSpacing.s2),
                          child: Text(notice.acknowledgmentLabel),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

- [x] `ConsentNotice` model created with `title`, `body`,
      `acknowledgmentLabel`
- [x] `SoliplexConfig.consentNotice` is optional (null by default)
- [x] Login screen shows interstitial when configured
- [x] Login options hidden until acknowledgment
- [x] No change when `consentNotice` is null
- [x] Responsive layout (2/3 width on desktop, full width on mobile)
- [x] Body rendered as markdown via `FlutterMarkdownPlusRenderer`
- [x] Acknowledgment button constrained to max 400px width
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
