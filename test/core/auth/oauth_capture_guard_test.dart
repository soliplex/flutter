import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/auth/callback_params.dart';
import 'package:soliplex_frontend/core/auth/oauth_capture_guard.dart';

void main() {
  group('OAuthCaptureGuard', () {
    late OAuthCaptureGuard guard;

    setUp(() {
      guard = OAuthCaptureGuard();
    });

    test('isCaptured returns false before capture', () {
      expect(guard.isCaptured, isFalse);
    });

    test('isCaptured returns true after capture', () {
      guard.capture(const NoCallbackParams());

      expect(guard.isCaptured, isTrue);
    });

    test('params throws StateError if accessed before capture', () {
      expect(
        () => guard.params,
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('OAuth params must be captured before'),
        )),
      );
    });

    test('params returns captured params after capture', () {
      const expected = WebCallbackParams(
        accessToken: 'test-token',
        refreshToken: 'test-refresh',
        expiresIn: 3600,
      );

      guard.capture(expected);

      expect(guard.params, same(expected));
    });

    test('capture throws if called twice', () {
      guard.capture(const NoCallbackParams());

      expect(
        () => guard.capture(const NoCallbackParams()),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('already been captured'),
        )),
      );
    });

    test('assertCaptured throws descriptive error if not captured', () {
      expect(
        () => guard.assertCaptured(),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('OAuth callback params were not captured'),
            contains('CallbackParamsCapture.captureNow()'),
            contains('before GoRouter'),
          ),
        )),
      );
    });

    test('assertCaptured does not throw if captured', () {
      guard.capture(const NoCallbackParams());

      expect(() => guard.assertCaptured(), returnsNormally);
    });

    test('reset allows capture to be called again', () {
      guard.capture(const NoCallbackParams());
      expect(guard.isCaptured, isTrue);

      guard.reset();

      expect(guard.isCaptured, isFalse);
      expect(
        () => guard.capture(const WebCallbackParams(accessToken: 'new-token')),
        returnsNormally,
      );
      expect(guard.params.hasError, isFalse);
    });
  });
}
