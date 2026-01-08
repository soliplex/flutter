import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/auth/auth_flow.dart';

void main() {
  group('AuthResult', () {
    test('stores required accessToken', () {
      const result = AuthResult(accessToken: 'access-123');

      expect(result.accessToken, 'access-123');
      expect(result.refreshToken, isNull);
      expect(result.idToken, isNull);
      expect(result.expiresAt, isNull);
    });

    test('stores all optional fields', () {
      final expiresAt = DateTime(2025, 12, 31);
      final result = AuthResult(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
        idToken: 'id-789',
        expiresAt: expiresAt,
      );

      expect(result.accessToken, 'access-123');
      expect(result.refreshToken, 'refresh-456');
      expect(result.idToken, 'id-789');
      expect(result.expiresAt, expiresAt);
    });
  });

  group('AuthException', () {
    test('stores message', () {
      const exception = AuthException('Authentication failed');

      expect(exception.message, 'Authentication failed');
    });

    test('toString includes message', () {
      const exception = AuthException('Token expired');

      expect(exception.toString(), 'AuthException: Token expired');
    });
  });

  group('AuthRedirectInitiated', () {
    test('toString returns descriptive message', () {
      const redirect = AuthRedirectInitiated();

      expect(
        redirect.toString(),
        'AuthRedirectInitiated: Browser redirecting to IdP',
      );
    });
  });
}
