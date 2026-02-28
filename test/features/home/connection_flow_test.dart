import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/features/home/connection_flow.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  group('probeConnection', () {
    late MockHttpTransport transport;

    setUp(() {
      transport = MockHttpTransport();
    });

    void stubRequest(Uri url, {Object? error}) {
      final invocation = when(
        () => transport.request<Map<String, dynamic>>(
          'GET',
          url,
          body: any(named: 'body'),
          headers: any(named: 'headers'),
          timeout: any(named: 'timeout'),
          cancelToken: any(named: 'cancelToken'),
          fromJson: any(named: 'fromJson'),
        ),
      );
      if (error != null) {
        invocation.thenThrow(error);
      } else {
        invocation.thenAnswer((_) async => <String, dynamic>{});
      }
    }

    test('returns success on HTTPS when input already has https', () async {
      stubRequest(Uri.parse('https://example.com/api/login'));

      final result = await probeConnection(
        input: 'https://example.com',
        transport: transport,
      );

      expect(result, isA<ConnectionSuccess>());
      final success = result as ConnectionSuccess;
      expect(success.url, Uri.parse('https://example.com'));
      expect(success.url.scheme, 'https');
    });

    test('returns success on HTTPS for bare hostname', () async {
      stubRequest(Uri.parse('https://example.com/api/login'));

      final result = await probeConnection(
        input: 'example.com',
        transport: transport,
      );

      expect(result, isA<ConnectionSuccess>());
      final success = result as ConnectionSuccess;
      expect(success.url, Uri.parse('https://example.com'));
      expect(success.url.scheme, 'https');
    });

    test('falls back to HTTP on HTTPS network error', () async {
      stubRequest(
        Uri.parse('https://example.com/api/login'),
        error: const NetworkException(message: 'connection refused'),
      );
      stubRequest(Uri.parse('http://example.com/api/login'));

      final result = await probeConnection(
        input: 'example.com',
        transport: transport,
      );

      expect(result, isA<ConnectionSuccess>());
      final success = result as ConnectionSuccess;
      expect(success.url, Uri.parse('http://example.com'));
      expect(success.url.scheme, 'http');
    });

    test('returns failure when both HTTPS and HTTP fail', () async {
      stubRequest(
        Uri.parse('https://example.com/api/login'),
        error: const NetworkException(message: 'connection refused'),
      );
      stubRequest(
        Uri.parse('http://example.com/api/login'),
        error: const NetworkException(message: 'connection refused'),
      );

      final result = await probeConnection(
        input: 'example.com',
        transport: transport,
      );

      expect(result, isA<ConnectionFailure>());
      final failure = result as ConnectionFailure;
      expect(failure.url, 'http://example.com');
    });

    test('returns failure for explicit https with network error', () async {
      stubRequest(
        Uri.parse('https://example.com/api/login'),
        error: const NetworkException(message: 'connection refused'),
      );

      final result = await probeConnection(
        input: 'https://example.com',
        transport: transport,
      );

      expect(result, isA<ConnectionFailure>());
      final failure = result as ConnectionFailure;
      expect(failure.url, 'https://example.com');
      // Should NOT have tried HTTP — user explicitly chose HTTPS.
      verifyNever(
        () => transport.request<Map<String, dynamic>>(
          'GET',
          Uri.parse('http://example.com/api/login'),
          body: any(named: 'body'),
          headers: any(named: 'headers'),
          timeout: any(named: 'timeout'),
          cancelToken: any(named: 'cancelToken'),
          fromJson: any(named: 'fromJson'),
        ),
      );
    });

    test('does not fall back to HTTP on non-network HTTPS error', () async {
      stubRequest(
        Uri.parse('https://example.com/api/login'),
        error: const ApiException(statusCode: 500, message: 'Internal error'),
      );

      final result = await probeConnection(
        input: 'example.com',
        transport: transport,
      );

      expect(result, isA<ConnectionFailure>());
      final failure = result as ConnectionFailure;
      expect(failure.url, 'https://example.com');
      // Should NOT have tried HTTP
      verifyNever(
        () => transport.request<Map<String, dynamic>>(
          'GET',
          Uri.parse('http://example.com/api/login'),
          body: any(named: 'body'),
          headers: any(named: 'headers'),
          timeout: any(named: 'timeout'),
          cancelToken: any(named: 'cancelToken'),
          fromJson: any(named: 'fromJson'),
        ),
      );
    });

    test('skips probing when input already has http scheme', () async {
      stubRequest(Uri.parse('http://localhost:8000/api/login'));

      final result = await probeConnection(
        input: 'http://localhost:8000',
        transport: transport,
      );

      expect(result, isA<ConnectionSuccess>());
      final success = result as ConnectionSuccess;
      expect(success.url, Uri.parse('http://localhost:8000'));
      expect(success.url.scheme, 'http');
      // Should NOT have tried HTTPS
      verifyNever(
        () => transport.request<Map<String, dynamic>>(
          'GET',
          Uri.parse('https://localhost:8000/api/login'),
          body: any(named: 'body'),
          headers: any(named: 'headers'),
          timeout: any(named: 'timeout'),
          cancelToken: any(named: 'cancelToken'),
          fromJson: any(named: 'fromJson'),
        ),
      );
    });

    test('preserves auth providers from successful probe', () async {
      when(
        () => transport.request<Map<String, dynamic>>(
          'GET',
          Uri.parse('https://example.com/api/login'),
          body: any(named: 'body'),
          headers: any(named: 'headers'),
          timeout: any(named: 'timeout'),
          cancelToken: any(named: 'cancelToken'),
          fromJson: any(named: 'fromJson'),
        ),
      ).thenAnswer(
        (_) async => <String, dynamic>{
          'google': {
            'title': 'Google',
            'server_url': 'https://accounts.google.com',
            'client_id': 'client-123',
            'scope': 'openid email',
          },
        },
      );

      final result = await probeConnection(
        input: 'example.com',
        transport: transport,
      );

      expect(result, isA<ConnectionSuccess>());
      final success = result as ConnectionSuccess;
      expect(success.providers, hasLength(1));
      expect(success.providers.first.name, 'Google');
    });

    test('handles hostname with port', () async {
      stubRequest(Uri.parse('https://example.com:8443/api/login'));

      final result = await probeConnection(
        input: 'example.com:8443',
        transport: transport,
      );

      expect(result, isA<ConnectionSuccess>());
      final success = result as ConnectionSuccess;
      expect(success.url, Uri.parse('https://example.com:8443'));
    });
  });

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

      test(
        'returns RequireLoginResult with exitNoAuthMode when NoAuthRequired',
        () {
          final result = determinePostConnectResult(
            hasProviders: true,
            currentAuthState: const NoAuthRequired(),
          );

          expect(result, isA<RequireLoginResult>());
          expect((result as RequireLoginResult).shouldExitNoAuthMode, isTrue);
        },
      );

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
        },
      );
    });
  });

  group('normalizeUri', () {
    test('removes trailing slash', () {
      expect(
        normalizeUri(Uri.parse('http://example.com/')),
        Uri.parse('http://example.com'),
      );
    });

    test('preserves URL without trailing slash', () {
      expect(
        normalizeUri(Uri.parse('http://example.com')),
        Uri.parse('http://example.com'),
      );
    });

    test('handles URL with path and trailing slash', () {
      expect(
        normalizeUri(Uri.parse('http://example.com/api/')),
        Uri.parse('http://example.com/api'),
      );
    });

    test('handles URL with port', () {
      expect(
        normalizeUri(Uri.parse('http://localhost:8000/')),
        Uri.parse('http://localhost:8000'),
      );
    });

    test('treats URLs differing only by trailing slash as equal', () {
      final url1 = normalizeUri(Uri.parse('http://example.com'));
      final url2 = normalizeUri(Uri.parse('http://example.com/'));
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
