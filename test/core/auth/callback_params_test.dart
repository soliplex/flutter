import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/auth/callback_params.dart';

void main() {
  group('WebCallbackParams', () {
    test('hasError returns false when error is null', () {
      const params = WebCallbackParams(accessToken: 'token');

      expect(params.hasError, isFalse);
    });

    test('hasError returns true when error is set', () {
      const params = WebCallbackParams(error: 'access_denied');

      expect(params.hasError, isTrue);
    });

    test('stores all constructor parameters', () {
      const params = WebCallbackParams(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
        expiresIn: 3600,
        error: 'error_code',
        errorDescription: 'Something went wrong',
      );

      expect(params.accessToken, 'access-123');
      expect(params.refreshToken, 'refresh-456');
      expect(params.expiresIn, 3600);
      expect(params.error, 'error_code');
      expect(params.errorDescription, 'Something went wrong');
    });

    test('toString shows token presence and expiry', () {
      const params = WebCallbackParams(
        accessToken: 'secret-token',
        refreshToken: 'secret-refresh',
        expiresIn: 3600,
      );

      final str = params.toString();

      expect(str, contains('hasAccessToken: true'));
      expect(str, contains('hasRefreshToken: true'));
      expect(str, contains('expiresIn: 3600'));
      // Should NOT contain actual token values
      expect(str, isNot(contains('secret-token')));
      expect(str, isNot(contains('secret-refresh')));
    });

    test('toString shows error when present', () {
      const params = WebCallbackParams(error: 'invalid_request');

      expect(params.toString(), contains('error: invalid_request'));
    });
  });

  group('NoCallbackParams', () {
    test('error is always null', () {
      const params = NoCallbackParams();

      expect(params.error, isNull);
    });

    test('hasError is always false', () {
      const params = NoCallbackParams();

      expect(params.hasError, isFalse);
    });

    test('toString returns NoCallbackParams()', () {
      const params = NoCallbackParams();

      expect(params.toString(), 'NoCallbackParams()');
    });
  });
}
