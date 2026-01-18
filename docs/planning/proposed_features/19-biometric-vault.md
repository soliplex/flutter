# Feature 19: Biometric Vault

## Usage
Certain "Projects" or "Threads" can be marked as "Secret". Viewing them requires FaceID/TouchID re-authentication.

## Specification
- **Library:** `local_auth`.
- **Encryption:** `flutter_secure_storage` key wrapping.

## Skeleton Code

```dart
import 'package:local_auth/local_auth.dart';

Future<bool> unlockVault() async {
  final LocalAuthentication auth = LocalAuthentication();
  return await auth.authenticate(
    localizedReason: 'Scan to access Secret Project',
    options: const AuthenticationOptions(biometricOnly: true),
  );
}
```

## Reviews

### Codex Review (Technical)
**Completeness:** High.
**Feasibility:** High.
**Novelty:** Medium.

### Skeptic Review (Product)
**Critique:** Essential for enterprise apps handling sensitive data.
