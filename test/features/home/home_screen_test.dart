import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/auth/auth_notifier.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/auth/oidc_issuer.dart';
import 'package:soliplex_frontend/core/models/app_config.dart';
import 'package:soliplex_frontend/core/models/logo_config.dart';
import 'package:soliplex_frontend/core/models/soliplex_config.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
import 'package:soliplex_frontend/features/home/home_screen.dart';

import '../../helpers/test_helpers.dart';

class _MockAuthNotifier extends Notifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier({AuthState? initialState})
      : _initialState = initialState ?? const Unauthenticated();

  final AuthState _initialState;
  bool signOutCalled = false;
  bool enterNoAuthModeCalled = false;
  bool exitNoAuthModeCalled = false;

  @override
  AuthState build() => _initialState;

  @override
  String? get accessToken => null;

  @override
  bool get needsRefresh => false;

  @override
  Future<void> signIn(OidcIssuer issuer) async {}

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    state = const Unauthenticated();
  }

  @override
  Future<void> refreshIfExpiringSoon() async {}

  @override
  Future<bool> tryRefresh() async => false;

  @override
  Future<void> completeWebAuth({
    required String accessToken,
    String? refreshToken,
    int? expiresIn,
  }) async {}

  @override
  Future<void> enterNoAuthMode() async {
    enterNoAuthModeCalled = true;
    state = const NoAuthRequired();
  }

  @override
  void exitNoAuthMode() {
    exitNoAuthModeCalled = true;
    state = const Unauthenticated();
  }
}

/// Creates a test app with GoRouter for testing navigation.
Widget _createAppWithRouter({
  required Widget home,
  required List<dynamic> overrides,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(body: home),
      ),
      GoRoute(
        path: '/rooms',
        builder: (_, __) => const Scaffold(body: Text('Rooms Screen')),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('Login Screen')),
      ),
    ],
  );

  return UncontrolledProviderScope(
    container: ProviderContainer(
      overrides: [
        // Default localhost:8000 matches test URLs so connecting is not
        // treated as a backend change (which triggers signOut).
        shellConfigProvider.overrideWithValue(
          const SoliplexConfig(logo: LogoConfig.soliplex),
        ),
        configProviderOverride(
          const AppConfig(baseUrl: 'https://localhost:8000'),
        ),
        ...overrides.cast(),
      ],
    ),
    child: MaterialApp.router(theme: testThemeData, routerConfig: router),
  );
}

/// Stubs [transport] to respond to any request with [response] or [error].
void _stubTransport(
  MockHttpTransport transport, {
  Map<String, dynamic>? response,
  Object? error,
}) {
  final invocation = when(
    () => transport.request<Map<String, dynamic>>(
      any(),
      any(),
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
    invocation.thenAnswer((_) async => response ?? <String, dynamic>{});
  }
}

/// Stubs [transport] to respond to a specific [method] + [url] combination.
void _stubTransportUrl(
  MockHttpTransport transport, {
  required String method,
  required Uri url,
  Map<String, dynamic>? response,
  Object? error,
}) {
  final invocation = when(
    () => transport.request<Map<String, dynamic>>(
      method,
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
    invocation.thenAnswer((_) async => response ?? <String, dynamic>{});
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  group('HomeScreen', () {
    group('UI', () {
      testWidgets('displays header and URL input', (tester) async {
        await tester.pumpWidget(createTestApp(home: const HomeScreen()));

        expect(find.text('Soliplex'), findsOneWidget);
        expect(
          find.text('Enter the URL of your backend server'),
          findsOneWidget,
        );
        expect(find.text('Backend URL'), findsOneWidget);
        expect(find.text('Connect'), findsOneWidget);
      });

      testWidgets('displays logo from config', (tester) async {
        const customLogo = LogoConfig(
          assetPath: 'assets/custom_logo.png',
          package: 'test_package',
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: ProviderContainer(
              overrides: [
                shellConfigProvider.overrideWithValue(
                  const SoliplexConfig(
                    oauthRedirectScheme: 'test.app',
                    logo: customLogo,
                  ),
                ),
              ],
            ),
            child: MaterialApp(
              theme: testThemeData,
              home: const Scaffold(body: HomeScreen()),
            ),
          ),
        );

        // Find the Image widget and verify its configuration
        final imageFinder = find.byType(Image);
        expect(imageFinder, findsOneWidget);

        final image = tester.widget<Image>(imageFinder);
        final assetImage = image.image as AssetImage;
        expect(assetImage.assetName, equals('assets/custom_logo.png'));
        expect(assetImage.package, equals('test_package'));
      });

      testWidgets('loads initial URL from config', (tester) async {
        await tester.pumpWidget(
          createTestApp(
            home: const HomeScreen(),
            overrides: [
              configProviderOverride(
                const AppConfig(baseUrl: 'https://custom.example.com'),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        final textField = tester.widget<TextFormField>(
          find.byType(TextFormField),
        );
        expect(textField.controller?.text, 'https://custom.example.com');
      });
    });

    group('validation', () {
      testWidgets('validates empty URL', (tester) async {
        await tester.pumpWidget(createTestApp(home: const HomeScreen()));

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, '');
        await tester.tap(find.text('Connect'));
        await tester.pump();

        expect(find.text('Server address is required'), findsOneWidget);
      });

      testWidgets('accepts valid http URL', (tester) async {
        await tester.pumpWidget(createTestApp(home: const HomeScreen()));

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'http://localhost:8000');
        await tester.tap(find.text('Connect'));
        await tester.pump();

        expect(find.text('Server address is required'), findsNothing);
      });

      testWidgets('accepts valid https URL', (tester) async {
        await tester.pumpWidget(createTestApp(home: const HomeScreen()));

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'https://api.example.com');
        await tester.tap(find.text('Connect'));
        await tester.pump();

        expect(find.text('Server address is required'), findsNothing);
      });

      testWidgets('accepts bare hostname without scheme', (tester) async {
        await tester.pumpWidget(createTestApp(home: const HomeScreen()));

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'myserver.example.com');
        await tester.tap(find.text('Connect'));
        await tester.pump();

        expect(find.text('Server address is required'), findsNothing);
      });

      testWidgets('accepts hostname with port without scheme', (tester) async {
        await tester.pumpWidget(createTestApp(home: const HomeScreen()));

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'myserver.example.com:8443');
        await tester.tap(find.text('Connect'));
        await tester.pump();

        expect(find.text('Server address is required'), findsNothing);
      });

      testWidgets('rejects URL with unsupported scheme', (tester) async {
        await tester.pumpWidget(createTestApp(home: const HomeScreen()));

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'ftp://myserver.com');
        await tester.tap(find.text('Connect'));
        await tester.pump();

        expect(
          find.text('Only http and https are supported'),
          findsOneWidget,
        );
      });

      testWidgets('rejects URL with spaces', (tester) async {
        await tester.pumpWidget(createTestApp(home: const HomeScreen()));

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'my server.com');
        await tester.tap(find.text('Connect'));
        await tester.pump();

        expect(find.text("Can't contain whitespaces"), findsOneWidget);
      });
    });

    group('connection errors', () {
      testWidgets('shows timeout error for NetworkException with timeout', (
        tester,
      ) async {
        final mockTransport = MockHttpTransport();
        _stubTransport(
          mockTransport,
          error: const NetworkException(message: 'timeout', isTimeout: true),
        );

        await tester.pumpWidget(
          createTestApp(
            home: const HomeScreen(),
            overrides: [httpTransportProvider.overrideWithValue(mockTransport)],
          ),
        );

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'http://localhost:8000');
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Connection to http://localhost:8000 timed out. '
            'The server may be slow or unreachable.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows network error for NetworkException', (tester) async {
        final mockTransport = MockHttpTransport();
        _stubTransport(
          mockTransport,
          error: const NetworkException(message: 'connection refused'),
        );

        await tester.pumpWidget(
          createTestApp(
            home: const HomeScreen(),
            overrides: [httpTransportProvider.overrideWithValue(mockTransport)],
          ),
        );

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'http://localhost:8000');
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Cannot reach http://localhost:8000. Check the URL and your '
            'network connection.\n\nDetails: connection refused',
          ),
          findsOneWidget,
        );
      });

      testWidgets(
        'shows server error for ApiException without server message',
        (tester) async {
          final mockTransport = MockHttpTransport();
          _stubTransport(
            mockTransport,
            error: const ApiException(statusCode: 500, message: 'HTTP 500'),
          );

          await tester.pumpWidget(
            createTestApp(
              home: const HomeScreen(),
              overrides: [
                httpTransportProvider.overrideWithValue(mockTransport),
              ],
            ),
          );

          final urlField = find.byType(TextFormField);
          await tester.enterText(urlField, 'http://localhost:8000');
          await tester.tap(find.text('Connect'));
          await tester.pumpAndSettle();

          expect(
            find.text(
              'Server error at http://localhost:8000. '
              'Please try again later. (500)',
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets('shows server error for ApiException with server message', (
        tester,
      ) async {
        final mockTransport = MockHttpTransport();
        _stubTransport(
          mockTransport,
          error: const ApiException(
            statusCode: 500,
            message: 'Database connection failed',
            serverMessage: 'Database connection failed',
          ),
        );

        await tester.pumpWidget(
          createTestApp(
            home: const HomeScreen(),
            overrides: [httpTransportProvider.overrideWithValue(mockTransport)],
          ),
        );

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'http://localhost:8000');
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Server error at http://localhost:8000. '
            'Please try again later. (500)\n\n'
            'Details: Database connection failed',
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows generic error for unknown exceptions', (tester) async {
        final mockTransport = MockHttpTransport();
        _stubTransport(
          mockTransport,
          error: Exception('Unknown error'),
        );

        await tester.pumpWidget(
          createTestApp(
            home: const HomeScreen(),
            overrides: [httpTransportProvider.overrideWithValue(mockTransport)],
          ),
        );

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'http://localhost:8000');
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Connection to http://localhost:8000 failed: '
            'Exception: Unknown error',
          ),
          findsOneWidget,
        );
      });
    });

    group('connection flow - no auth providers', () {
      testWidgets('enters no-auth mode and navigates to rooms', (tester) async {
        final mockTransport = MockHttpTransport();
        _stubTransport(mockTransport);

        late _MockAuthNotifier mockAuth;

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const HomeScreen(),
            overrides: [
              httpTransportProvider.overrideWithValue(mockTransport),
              authProvider.overrideWith(() {
                return mockAuth = _MockAuthNotifier();
              }),
            ],
          ),
        );

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'https://localhost:8000');
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();

        expect(mockAuth.enterNoAuthModeCalled, isTrue);
        expect(find.text('Rooms Screen'), findsOneWidget);
      });
    });

    group('connection flow - with auth providers', () {
      const googleProviderResponse = <String, dynamic>{
        'google': {
          'title': 'Google',
          'server_url': 'https://accounts.google.com',
          'client_id': 'client-123',
          'scope': 'openid email',
        },
      };

      testWidgets('navigates to login when unauthenticated', (tester) async {
        final mockTransport = MockHttpTransport();
        _stubTransport(mockTransport, response: googleProviderResponse);

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const HomeScreen(),
            overrides: [
              httpTransportProvider.overrideWithValue(mockTransport),
              authProvider.overrideWith(_MockAuthNotifier.new),
            ],
          ),
        );

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'https://localhost:8000');
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();

        expect(find.text('Login Screen'), findsOneWidget);
      });

      testWidgets('navigates to rooms when already authenticated', (
        tester,
      ) async {
        final mockTransport = MockHttpTransport();
        _stubTransport(mockTransport, response: googleProviderResponse);

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const HomeScreen(),
            overrides: [
              httpTransportProvider.overrideWithValue(mockTransport),
              authProvider.overrideWith(
                () => _MockAuthNotifier(
                  initialState: TestData.createAuthenticated(),
                ),
              ),
            ],
          ),
        );

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'https://localhost:8000');
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();

        expect(find.text('Rooms Screen'), findsOneWidget);
      });

      testWidgets('exits no-auth mode and navigates to login when switching', (
        tester,
      ) async {
        final mockTransport = MockHttpTransport();
        _stubTransport(mockTransport, response: googleProviderResponse);

        late _MockAuthNotifier mockAuth;

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const HomeScreen(),
            overrides: [
              httpTransportProvider.overrideWithValue(mockTransport),
              authProvider.overrideWith(() {
                return mockAuth = _MockAuthNotifier(
                  initialState: const NoAuthRequired(),
                );
              }),
            ],
          ),
        );

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'https://localhost:8000');
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();

        // Should exit no-auth mode before navigating to login
        expect(mockAuth.exitNoAuthModeCalled, isTrue);
        expect(find.text('Login Screen'), findsOneWidget);
      });
    });

    group('insecure connection warning', () {
      /// Stubs [transport] so HTTPS fails with a network error and HTTP
      /// succeeds, triggering the insecure-connection fallback path.
      void stubHttpFallback(MockHttpTransport transport) {
        _stubTransportUrl(
          transport,
          method: 'GET',
          url: Uri.parse('https://example.com/api/login'),
          error: const NetworkException(message: 'connection refused'),
        );
        _stubTransportUrl(
          transport,
          method: 'GET',
          url: Uri.parse('http://example.com/api/login'),
        );
      }

      testWidgets('shows warning when connecting over HTTP via fallback', (
        tester,
      ) async {
        final mockTransport = MockHttpTransport();
        stubHttpFallback(mockTransport);

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const HomeScreen(),
            overrides: [
              httpTransportProvider.overrideWithValue(mockTransport),
              authProvider.overrideWith(_MockAuthNotifier.new),
            ],
          ),
        );

        // Use pump() not pumpAndSettle() — the spinner animates behind
        // the modal dialog, so pumpAndSettle never finishes.
        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'example.com');
        await tester.tap(find.text('Connect'));
        await tester.pump();
        await tester.pump();

        // Should show insecurity warning dialog
        expect(find.text('Insecure Connection'), findsOneWidget);
        expect(
          find.textContaining('not encrypted'),
          findsOneWidget,
        );
      });

      testWidgets('proceeds when user accepts insecure connection', (
        tester,
      ) async {
        final mockTransport = MockHttpTransport();
        stubHttpFallback(mockTransport);

        late _MockAuthNotifier mockAuth;

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const HomeScreen(),
            overrides: [
              httpTransportProvider.overrideWithValue(mockTransport),
              authProvider.overrideWith(() {
                return mockAuth = _MockAuthNotifier();
              }),
            ],
          ),
        );

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'example.com');
        await tester.tap(find.text('Connect'));
        await tester.pump();
        await tester.pump();

        // Accept the warning — dismissing the dialog clears _isConnecting
        // via finally, so pumpAndSettle works after this point.
        await tester.tap(find.text('I understand, connect anyway'));
        await tester.pumpAndSettle();

        // Should proceed to rooms (no auth providers = no-auth mode)
        expect(mockAuth.enterNoAuthModeCalled, isTrue);
        expect(find.text('Rooms Screen'), findsOneWidget);
      });

      testWidgets('cancels when user declines insecure connection', (
        tester,
      ) async {
        final mockTransport = MockHttpTransport();
        stubHttpFallback(mockTransport);

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const HomeScreen(),
            overrides: [
              httpTransportProvider.overrideWithValue(mockTransport),
              authProvider.overrideWith(_MockAuthNotifier.new),
            ],
          ),
        );

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'example.com');
        await tester.tap(find.text('Connect'));
        await tester.pump();
        await tester.pump();

        // Decline the warning — dismissing the dialog clears _isConnecting
        // via finally, so pumpAndSettle works after this point.
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Should stay on home screen
        expect(find.text('Rooms Screen'), findsNothing);
        expect(find.text('Connect'), findsOneWidget);
      });

      testWidgets('shows warning when user explicitly types http://', (
        tester,
      ) async {
        final mockTransport = MockHttpTransport();
        _stubTransportUrl(
          mockTransport,
          method: 'GET',
          url: Uri.parse('http://localhost:8000/api/login'),
        );

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const HomeScreen(),
            overrides: [
              httpTransportProvider.overrideWithValue(mockTransport),
              authProvider.overrideWith(_MockAuthNotifier.new),
            ],
          ),
        );

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'http://localhost:8000');
        await tester.tap(find.text('Connect'));
        await tester.pump();
        await tester.pump();

        // Should show insecurity warning
        expect(find.text('Insecure Connection'), findsOneWidget);
      });

      testWidgets('no warning for HTTPS connection', (tester) async {
        final mockTransport = MockHttpTransport();
        _stubTransportUrl(
          mockTransport,
          method: 'GET',
          url: Uri.parse('https://example.com/api/login'),
        );

        late _MockAuthNotifier mockAuth;

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const HomeScreen(),
            overrides: [
              httpTransportProvider.overrideWithValue(mockTransport),
              authProvider.overrideWith(() {
                return mockAuth = _MockAuthNotifier();
              }),
            ],
          ),
        );

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'example.com');
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();

        // No warning, should go directly to rooms
        expect(find.text('Insecure Connection'), findsNothing);
        expect(mockAuth.enterNoAuthModeCalled, isTrue);
        expect(find.text('Rooms Screen'), findsOneWidget);
      });
    });

    group('connecting state', () {
      testWidgets('shows loading indicator while connecting', (tester) async {
        final completer = Completer<Map<String, dynamic>>();
        final mockTransport = MockHttpTransport();
        when(
          () => mockTransport.request<Map<String, dynamic>>(
            any(),
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
            timeout: any(named: 'timeout'),
            cancelToken: any(named: 'cancelToken'),
            fromJson: any(named: 'fromJson'),
          ),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const HomeScreen(),
            overrides: [
              httpTransportProvider.overrideWithValue(mockTransport),
              authProvider.overrideWith(_MockAuthNotifier.new),
            ],
          ),
        );

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'https://localhost:8000');
        await tester.tap(find.text('Connect'));
        await tester.pump();

        // Should show loading indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Complete to clean up (empty = no auth providers = no-auth mode)
        completer.complete(<String, dynamic>{});
        await tester.pumpAndSettle();
      });

      testWidgets('disables input while connecting', (tester) async {
        final completer = Completer<Map<String, dynamic>>();
        final mockTransport = MockHttpTransport();
        when(
          () => mockTransport.request<Map<String, dynamic>>(
            any(),
            any(),
            body: any(named: 'body'),
            headers: any(named: 'headers'),
            timeout: any(named: 'timeout'),
            cancelToken: any(named: 'cancelToken'),
            fromJson: any(named: 'fromJson'),
          ),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(
          _createAppWithRouter(
            home: const HomeScreen(),
            overrides: [
              httpTransportProvider.overrideWithValue(mockTransport),
              authProvider.overrideWith(_MockAuthNotifier.new),
            ],
          ),
        );

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'https://localhost:8000');
        await tester.tap(find.text('Connect'));
        await tester.pump();

        // Text field should be disabled
        final textField = tester.widget<TextFormField>(urlField);
        expect(textField.enabled, isFalse);

        // Complete to clean up
        completer.complete(<String, dynamic>{});
        await tester.pumpAndSettle();
      });
    });
  });
}
