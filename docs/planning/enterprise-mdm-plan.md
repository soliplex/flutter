# Enterprise MDM Implementation Plan

## Overview

Transform Soliplex Flutter from a build-time whitelabel solution into an
enterprise-ready platform with runtime MDM configuration, security controls,
and compliance features.

## Implementation Status

### Completed (Reverted - Code Available)

The following was implemented and tested but reverted to keep the appshell
extraction branch clean. Code patterns are documented here for re-implementation.

| Component | File | Status |
|-----------|------|--------|
| SecurityPolicy model | `lib/core/models/security_policy.dart` | Designed |
| AuditEvent model | `lib/core/models/audit_event.dart` | Designed |
| EnterpriseConfig model | `lib/core/models/enterprise_config.dart` | Designed |
| MdmService | `lib/core/services/mdm_service.dart` | Designed |
| Android AppRestrictions XML | `android/.../res/xml/app_restrictions.xml` | Designed |
| Android MethodChannel | `MainActivity.kt` | Designed |
| iOS MethodChannel | `MdmConfigChannel.swift` | Designed |
| Enterprise Riverpod providers | `lib/core/providers/enterprise_providers.dart` | Designed |

---

## Phase 1: MDM Foundation

**Goal:** Runtime configuration from MDM systems (Intune, Workspace ONE, Jamf)

### 1.1 Core Models

#### SecurityPolicy

```dart
/// lib/core/models/security_policy.dart
@immutable
class SecurityPolicy {
  const SecurityPolicy({
    this.allowCopyPaste = true,
    this.allowScreenshots = true,
    this.jailbreakPolicy = JailbreakPolicy.warn,
    this.requireBiometric = false,
    this.certificatePinningEnabled = true,
    this.sessionTimeoutMinutes = 30,
    this.allowExternalSharing = true,
    this.auditLoggingEnabled = true,
    this.remoteWipeEnabled = true,
  });

  factory SecurityPolicy.fromMdmConfig(Map<String, dynamic>? config);
}

enum JailbreakPolicy { block, warn, allow }
```

#### EnterpriseConfig

```dart
/// lib/core/models/enterprise_config.dart
class EnterpriseConfig {
  EnterpriseConfig({
    required this.staticConfig,  // Compile-time SoliplexConfig
    Map<String, dynamic>? mdmConfig,
  });

  // Dynamic getters with MDM overrides
  String get apiEndpoint => _mdmConfig['api_endpoint'] ?? staticConfig.defaultBackendUrl;
  SecurityPolicy get securityPolicy => SecurityPolicy.fromMdmConfig(_mdmConfig['security_policy']);
  IdpConfig get idpConfig => IdpConfig.fromMdmConfig(_mdmConfig['idp']);

  // Change notifications
  Stream<void> get onConfigChanged;
}
```

### 1.2 Platform Channels

#### Android (RestrictionsManager)

```xml
<!-- android/app/src/main/res/xml/app_restrictions.xml -->
<restrictions xmlns:android="http://schemas.android.com/apk/res/android">
    <restriction android:key="api_endpoint" android:restrictionType="string" />
    <restriction android:key="organization_name" android:restrictionType="string" />
    <restriction android:key="security_policy" android:restrictionType="bundle">
        <restriction android:key="allow_copy_paste" android:restrictionType="bool" />
        <restriction android:key="allow_screenshots" android:restrictionType="bool" />
        <restriction android:key="jailbreak_policy" android:restrictionType="choice" />
    </restriction>
</restrictions>
```

```kotlin
// MainActivity.kt - Read via RestrictionsManager
val restrictionsManager = getSystemService(Context.RESTRICTIONS_SERVICE) as RestrictionsManager
val config = restrictionsManager.applicationRestrictions
```

#### iOS (Managed App Configuration)

```swift
// Read via UserDefaults
let config = UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed")
```

### 1.3 Riverpod Integration

```dart
/// lib/core/providers/enterprise_providers.dart

// Initialize before runApp()
Future<void> initializeMdmService() async {
  _mdmService = createMdmService();
  await _mdmService.initialize();
}

// Providers
final mdmServiceProvider = Provider<MdmService>((ref) => _mdmService);

final enterpriseConfigProvider = NotifierProvider<EnterpriseConfigNotifier, EnterpriseConfig>(
  EnterpriseConfigNotifier.new,
);

final securityPolicyProvider = Provider<SecurityPolicy>((ref) {
  return ref.watch(enterpriseConfigProvider).securityPolicy;
});
```

### 1.4 Dependencies

```yaml
# pubspec.yaml additions for Phase 1
dependencies:
  flutter_secure_storage: ^10.0.0  # Already present
  local_auth: ^3.0.0               # Biometric auth
  flutter_jailbreak_detection: ^1.10.0
```

### 1.5 Validation Checklist

- [ ] MDM config reads from Intune test profile
- [ ] MDM config reads from Workspace ONE test profile
- [ ] Config changes trigger provider updates
- [ ] Fallback to compile-time defaults works
- [ ] Unit tests for all models
- [ ] Integration test with mock MDM config

---

## Phase 2: Security Services

**Goal:** Certificate pinning, jailbreak detection, DLP enforcement

### 2.1 SecurityService

```dart
/// lib/core/services/security_service.dart
class SecurityService {
  Future<SecurityCheckResult> performStartupChecks();
  Future<bool> isDeviceCompromised();
  void enforceDlpPolicy(SecurityPolicy policy);
}

class SecurityCheckResult {
  final bool isJailbroken;
  final bool passedIntegrityCheck;
  final JailbreakPolicy recommendedAction;
}
```

### 2.2 Certificate Pinning

```dart
// Dio interceptor for SPKI pinning
class CertificatePinningInterceptor extends Interceptor {
  CertificatePinningInterceptor({
    required List<String> pins,
    String? backupPin,
    bool enabled = true,
  });
}
```

### 2.3 DLP Enforcement

| Control | Android | iOS |
|---------|---------|-----|
| Block screenshots | `FLAG_SECURE` on window | Screen capture detection |
| Block copy/paste | Custom `TextSelectionControls` | Custom `TextSelectionControls` |
| Block sharing | Disable share intents | Disable `UIActivityViewController` |

### 2.4 Startup Security Flow

```
App Launch
    │
    ▼
┌─────────────────┐
│ MDM Config Load │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌──────────────┐
│ Jailbreak Check │────▶│ Block Screen │ (if policy = block)
└────────┬────────┘     └──────────────┘
         │
         ▼ (if policy = warn)
┌─────────────────┐
│ Warning Dialog  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Biometric Auth  │ (if required)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Main App      │
└─────────────────┘
```

---

## Phase 3: Audit Logging

**Goal:** Tamper-evident logging with SIEM export

### 3.1 AuditEvent Model

```dart
@immutable
class AuditEvent {
  final String eventId;
  final String eventType;      // e.g., 'auth.login', 'security.jailbreak_detected'
  final AuditEventCategory category;
  final AuditEventSeverity severity;
  final DateTime timestamp;
  final Map<String, dynamic> details;
  final bool containsPii;
  final String? userId;
  final String? deviceId;
}

enum AuditEventCategory { authentication, security, dataAccess, configuration, system }
enum AuditEventSeverity { info, warning, critical }
```

### 3.2 AuditService

```dart
class AuditService {
  Future<void> log(AuditEvent event);
  Future<List<AuditEvent>> getUnsynced();
  Future<void> markSynced(List<String> eventIds);
  Future<void> syncToBackend();
}
```

### 3.3 Local Storage

```sql
-- SQLite schema (encrypted with SQLCipher)
CREATE TABLE audit_events (
  event_id TEXT PRIMARY KEY,
  event_type TEXT NOT NULL,
  category TEXT NOT NULL,
  severity TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  details TEXT,  -- JSON
  contains_pii INTEGER DEFAULT 0,
  user_id TEXT,
  device_id TEXT,
  synced INTEGER DEFAULT 0
);
```

### 3.4 Background Sync

```dart
// Using workmanager package
Workmanager().registerPeriodicTask(
  'audit-sync',
  'syncAuditLogs',
  frequency: Duration(minutes: 15),
  constraints: Constraints(networkType: NetworkType.connected),
);
```

---

## Phase 4: Remote Wipe

**Goal:** MDM-triggered data destruction

### 4.1 WipeService

```dart
class WipeService {
  Future<void> performWipe();
  Future<bool> checkWipeStatus();  // Called on app launch
  Future<void> acknowledgeWipe();
}
```

### 4.2 Wipe Triggers

1. **Push notification** - Silent push with wipe command
2. **Startup check** - Poll backend for wipe flag
3. **MDM command** - Platform-specific MDM wipe

### 4.3 Data to Wipe

| Data | Location | Method |
|------|----------|--------|
| Auth tokens | Secure storage | `deleteAll()` |
| User preferences | SharedPreferences | `clear()` |
| Chat history | SQLite | Delete database file |
| Cached files | App cache dir | `Directory.delete()` |
| Encryption keys | Keychain/Keystore | Platform-specific |

### 4.4 Wipe Flow

```
Wipe Trigger
    │
    ▼
┌─────────────────┐
│ Log wipe event  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Delete all data │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Ack to backend  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Show wipe screen│
└─────────────────┘
```

---

## Phase 5: Enterprise Auth (SSO)

**Goal:** SAML 2.0 and multi-tenant IdP support

### 5.1 IdpConfig

```dart
class IdpConfig {
  final IdpType type;  // oauth, oidc, saml
  final String? authority;
  final String? clientId;
  final String? tenantId;
  final List<String> scopes;
}

enum IdpType { oauth, oidc, saml }
```

### 5.2 SAML Flow

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│  App    │     │ WebView │     │   IdP   │     │ Backend │
└────┬────┘     └────┬────┘     └────┬────┘     └────┬────┘
     │               │               │               │
     │──── Open ────▶│               │               │
     │               │── Auth Req ──▶│               │
     │               │               │               │
     │               │◀── SAML ─────│               │
     │               │   Response    │               │
     │               │               │               │
     │◀── Deep ─────│               │               │
     │    Link       │               │               │
     │               │               │               │
     │─────────────── SAML Assertion ──────────────▶│
     │               │               │               │
     │◀────────────── JWT Token ───────────────────│
     │               │               │               │
```

### 5.3 Multi-tenant Support

```dart
// IdP config comes from MDM per-tenant
final idpConfig = ref.watch(idpConfigProvider);

// Authority URL is tenant-specific
final authority = idpConfig.authority;  // e.g., 'https://login.microsoftonline.com/{tenant}'
```

---

## File Structure

```
lib/
├── core/
│   ├── models/
│   │   ├── enterprise_config.dart
│   │   ├── security_policy.dart
│   │   └── audit_event.dart
│   ├── services/
│   │   ├── mdm_service.dart
│   │   ├── security_service.dart
│   │   ├── audit_service.dart
│   │   └── wipe_service.dart
│   └── providers/
│       └── enterprise_providers.dart
├── features/
│   └── security/
│       ├── jailbreak_screen.dart
│       └── wipe_screen.dart

android/
├── app/src/main/
│   ├── kotlin/.../MainActivity.kt  (MDM channel)
│   └── res/xml/app_restrictions.xml

ios/
└── Runner/
    └── MdmConfigChannel.swift
```

---

## Dependencies Summary

```yaml
dependencies:
  # Security
  flutter_secure_storage: ^10.0.0  # Already present
  flutter_jailbreak_detection: ^1.10.0
  local_auth: ^3.0.0

  # Database
  sqflite: ^2.4.2
  sqflite_sqlcipher: ^3.4.0  # Encrypted SQLite

  # Background tasks
  workmanager: ^0.9.0+3

  # Monitoring (optional)
  sentry_flutter: ^9.10.0
```

---

## Testing Strategy

### Unit Tests

- SecurityPolicy parsing from various MDM configs
- AuditEvent serialization/deserialization
- EnterpriseConfig MDM override logic

### Integration Tests

- MDM config flow with mock platform channel
- Audit log persistence and sync
- Wipe service data destruction verification

### Manual Testing

- Intune test tenant configuration
- Workspace ONE test environment
- Jailbroken device behavior
- SAML flow with Azure AD / Okta

---

## Rollout Plan

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| 1. MDM Foundation | 2 weeks | Runtime config from MDM |
| 2. Security Services | 2 weeks | Pinning, jailbreak, DLP |
| 3. Audit Logging | 1 week | Local + backend sync |
| 4. Remote Wipe | 1 week | MDM-triggered wipe |
| 5. Enterprise Auth | 2 weeks | SAML 2.0, multi-tenant |

**Total:** ~8 weeks for full enterprise capability
