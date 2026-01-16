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
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/package_info_provider.dart';
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
      GoRoute(path: '/', builder: (_, __) => Scaffold(body: home)),
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
        packageInfoProvider.overrideWithValue(testPackageInfo),
        ...overrides.cast(),
      ],
    ),
    child: MaterialApp.router(theme: testThemeData, routerConfig: router),
  );
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
      testWidgets('validates URL format', (tester) async {
        await tester.pumpWidget(createTestApp(home: const HomeScreen()));

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'invalid-url');
        await tester.tap(find.text('Connect'));
        await tester.pump();

        expect(
          find.text('URL must start with http:// or https://'),
          findsOneWidget,
        );
      });

      testWidgets('validates empty URL', (tester) async {
        await tester.pumpWidget(createTestApp(home: const HomeScreen()));

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, '');
        await tester.tap(find.text('Connect'));
        await tester.pump();

        expect(find.text('Please enter a server URL'), findsOneWidget);
      });

      testWidgets('accepts valid http URL', (tester) async {
        await tester.pumpWidget(createTestApp(home: const HomeScreen()));

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'http://localhost:8000');
        await tester.tap(find.text('Connect'));
        await tester.pump();

        // No validation error should appear
        expect(find.text('Please enter a server URL'), findsNothing);
        expect(
          find.text('URL must start with http:// or https://'),
          findsNothing,
        );
      });

      testWidgets('accepts valid https URL', (tester) async {
        await tester.pumpWidget(createTestApp(home: const HomeScreen()));

        final urlField = find.byType(TextFormField);
        await tester.enterText(urlField, 'https://api.example.com');
        await tester.tap(find.text('Connect'));
        await tester.pump();

        // No validation error should appear
        expect(find.text('Please enter a server URL'), findsNothing);
        expect(
          find.text('URL must start with http:// or https://'),
          findsNothing,
        );
      });
    });

    group('connection errors', () {
      testWidgets('shows timeout error for NetworkException with timeout',
          (tester) async {
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
        ).thenThrow(
          const NetworkException(message: 'timeout', isTimeout: true),
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
          find.text('Request timed out. Please try again.'),
          findsOneWidget,
        );
      });

      testWidgets('shows network error for NetworkException', (tester) async {
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
        ).thenThrow(const NetworkException(message: 'connection refused'));

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
            'Cannot reach server. '
            'Verify the URL is correct and the server is running.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows server error for ApiException', (tester) async {
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
        ).thenThrow(
          const ApiException(statusCode: 500, message: 'Server error'),
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
            'Server error (500). '
            'Please try again later or verify the backend URL is correct.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows generic error for unknown exceptions', (tester) async {
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
        ).thenThrow(Exception('Unknown error'));

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
          find.text('Connection failed: Exception: Unknown error'),
          findsOneWidget,
        );
      });
    });

    group('connection flow - no auth providers', () {
      testWidgets('enters no-auth mode and navigates to rooms', (tester) async {
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
        ).thenAnswer((_) async => <String, dynamic>{});

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
        await tester.enterText(urlField, 'http://localhost:8000');
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();

        expect(mockAuth.enterNoAuthModeCalled, isTrue);
        expect(find.text('Rooms Screen'), findsOneWidget);
      });
    });

    group('connection flow - with auth providers', () {
      testWidgets('navigates to login when unauthenticated', (tester) async {
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
        await tester.pumpAndSettle();

        expect(find.text('Login Screen'), findsOneWidget);
      });

      testWidgets('navigates to rooms when already authenticated',
          (tester) async {
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
        await tester.enterText(urlField, 'http://localhost:8000');
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();

        expect(find.text('Rooms Screen'), findsOneWidget);
      });

      testWidgets('exits no-auth mode and navigates to login when switching',
          (tester) async {
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
        await tester.enterText(urlField, 'http://localhost:8000');
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();

        // Should exit no-auth mode before navigating to login
        expect(mockAuth.exitNoAuthModeCalled, isTrue);
        expect(find.text('Login Screen'), findsOneWidget);
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
        await tester.enterText(urlField, 'http://localhost:8000');
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
        await tester.enterText(urlField, 'http://localhost:8000');
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
