import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/features/home/connection_flow.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('determinePreConnectAction', () {
    group('when backend has not changed', () {
      test('returns none regardless of auth state', () {
        expect(
          determinePreConnectAction(
            isBackendChange: false,
            currentAuthState: TestData.createAuthenticated(),
          ),
          PreConnectAction.none,
        );

        expect(
          determinePreConnectAction(
            isBackendChange: false,
            currentAuthState: const NoAuthRequired(),
          ),
          PreConnectAction.none,
        );

        expect(
          determinePreConnectAction(
            isBackendChange: false,
            currentAuthState: const Unauthenticated(),
          ),
          PreConnectAction.none,
        );
      });
    });

    group('when backend has changed', () {
      test('returns signOut when currently Authenticated', () {
        expect(
          determinePreConnectAction(
            isBackendChange: true,
            currentAuthState: TestData.createAuthenticated(),
          ),
          PreConnectAction.signOut,
        );
      });

      test('returns exitNoAuthMode when currently NoAuthRequired', () {
        expect(
          determinePreConnectAction(
            isBackendChange: true,
            currentAuthState: const NoAuthRequired(),
          ),
          PreConnectAction.exitNoAuthMode,
        );
      });

      test('returns none when currently Unauthenticated', () {
        expect(
          determinePreConnectAction(
            isBackendChange: true,
            currentAuthState: const Unauthenticated(),
          ),
          PreConnectAction.none,
        );
      });

      test('returns none when currently AuthLoading', () {
        expect(
          determinePreConnectAction(
            isBackendChange: true,
            currentAuthState: const AuthLoading(),
          ),
          PreConnectAction.none,
        );
      });
    });
  });

  group('determinePostConnectResult', () {
    group('when backend has no providers (no-auth mode)', () {
      test('returns EnterNoAuthModeResult regardless of auth state', () {
        expect(
          determinePostConnectResult(
            hasProviders: false,
            currentAuthState: const Unauthenticated(),
          ),
          isA<EnterNoAuthModeResult>(),
        );

        expect(
          determinePostConnectResult(
            hasProviders: false,
            currentAuthState: TestData.createAuthenticated(),
          ),
          isA<EnterNoAuthModeResult>(),
        );

        expect(
          determinePostConnectResult(
            hasProviders: false,
            currentAuthState: const NoAuthRequired(),
          ),
          isA<EnterNoAuthModeResult>(),
        );
      });
    });

    group('when backend has providers (auth required)', () {
      test('returns AlreadyAuthenticatedResult when Authenticated', () {
        expect(
          determinePostConnectResult(
            hasProviders: true,
            currentAuthState: TestData.createAuthenticated(),
          ),
          isA<AlreadyAuthenticatedResult>(),
        );
      });

      test('returns RequireLoginResult with exitNoAuthMode when NoAuthRequired',
          () {
        final result = determinePostConnectResult(
          hasProviders: true,
          currentAuthState: const NoAuthRequired(),
        );

        expect(result, isA<RequireLoginResult>());
        expect((result as RequireLoginResult).shouldExitNoAuthMode, isTrue);
      });

      test(
          'returns RequireLoginResult without exitNoAuthMode when '
          'Unauthenticated', () {
        final result = determinePostConnectResult(
          hasProviders: true,
          currentAuthState: const Unauthenticated(),
        );

        expect(result, isA<RequireLoginResult>());
        expect((result as RequireLoginResult).shouldExitNoAuthMode, isFalse);
      });

      test(
          'returns RequireLoginResult without exitNoAuthMode when AuthLoading',
          () {
        final result = determinePostConnectResult(
          hasProviders: true,
          currentAuthState: const AuthLoading(),
        );

        expect(result, isA<RequireLoginResult>());
        expect((result as RequireLoginResult).shouldExitNoAuthMode, isFalse);
      });
    });
  });

  group('normalizeUrl', () {
    test('removes trailing slash', () {
      expect(normalizeUrl('http://example.com/'), 'http://example.com');
    });

    test('preserves URL without trailing slash', () {
      expect(normalizeUrl('http://example.com'), 'http://example.com');
    });

    test('handles URL with path and trailing slash', () {
      expect(normalizeUrl('http://example.com/api/'), 'http://example.com/api');
    });

    test('handles URL with port', () {
      expect(normalizeUrl('http://localhost:8000/'), 'http://localhost:8000');
    });

    test('treats URLs differing only by trailing slash as equal', () {
      final url1 = normalizeUrl('http://example.com');
      final url2 = normalizeUrl('http://example.com/');
      expect(url1, equals(url2));
    });
  });

  group('PostConnectResult equality', () {
    test('EnterNoAuthModeResult instances are equal', () {
      expect(
        const EnterNoAuthModeResult(),
        equals(const EnterNoAuthModeResult()),
      );
    });

    test('AlreadyAuthenticatedResult instances are equal', () {
      expect(
        const AlreadyAuthenticatedResult(),
        equals(const AlreadyAuthenticatedResult()),
      );
    });

    test('RequireLoginResult equality based on shouldExitNoAuthMode', () {
      expect(
        const RequireLoginResult(shouldExitNoAuthMode: true),
        equals(const RequireLoginResult(shouldExitNoAuthMode: true)),
      );

      expect(
        const RequireLoginResult(shouldExitNoAuthMode: true),
        isNot(equals(const RequireLoginResult(shouldExitNoAuthMode: false))),
      );
    });
  });
}
