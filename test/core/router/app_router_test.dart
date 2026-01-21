import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_frontend/core/auth/auth_notifier.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/auth/callback_params.dart';
import 'package:soliplex_frontend/core/models/features.dart';
import 'package:soliplex_frontend/core/models/route_config.dart';
import 'package:soliplex_frontend/core/models/soliplex_config.dart';
import 'package:soliplex_frontend/core/providers/backend_version_provider.dart';
import 'package:soliplex_frontend/core/providers/package_info_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/core/router/app_router.dart';
import 'package:soliplex_frontend/features/auth/auth_callback_screen.dart';
import 'package:soliplex_frontend/features/home/home_screen.dart';
import 'package:soliplex_frontend/features/login/login_screen.dart';
import 'package:soliplex_frontend/features/quiz/quiz_screen.dart';
import 'package:soliplex_frontend/features/room/room_screen.dart';
import 'package:soliplex_frontend/features/rooms/rooms_screen.dart';
import 'package:soliplex_frontend/features/settings/settings_screen.dart';

import '../../helpers/test_helpers.dart';

Authenticated _createAuthenticatedState() => Authenticated(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      issuerId: 'test-issuer',
      issuerDiscoveryUrl:
          'https://sso.example.com/.well-known/openid-configuration',
      clientId: 'test-client',
      idToken: 'test-id-token',
    );

AuthState _resolveAuthState({
  bool authenticated = true,
  bool noAuthMode = false,
}) {
  if (noAuthMode) return const NoAuthRequired();
  if (authenticated) return _createAuthenticatedState();
  return const Unauthenticated();
}

class _MockAuthNotifier extends AuthNotifier {
  _MockAuthNotifier(this._initialState);
  final AuthState _initialState;

  @override
  AuthState build() => _initialState;
}

// Using dynamic list since Override type is internal in Riverpod 3.0
Widget createRouterApp({
  List<dynamic> overrides = const [],
  bool authenticated = true,
  bool noAuthMode = false,
}) {
  return createRouterAppAt(
    '/',
    overrides: overrides,
    authenticated: authenticated,
    noAuthMode: noAuthMode,
  );
}

List<dynamic> roomScreenOverrides(String roomId) {
  return [
    threadsProvider(roomId).overrideWith((ref) async => []),
    lastViewedThreadProvider(roomId).overrideWith(
      (ref) async => const NoLastViewed(),
    ),
    roomsProvider.overrideWith(
      (ref) async => [TestData.createRoom(id: roomId)],
    ),
  ];
}

Widget createRouterAppAt(
  String initialLocation, {
  List<dynamic> overrides = const [],
  bool authenticated = true,
  bool noAuthMode = false,
}) {
  final authState = _resolveAuthState(
    authenticated: authenticated,
    noAuthMode: noAuthMode,
  );

  return ProviderScope(
    overrides: [
      packageInfoProvider.overrideWithValue(testPackageInfo),
      shellConfigProvider.overrideWithValue(const SoliplexConfig()),
      authProvider.overrideWith(() => _MockAuthNotifier(authState)),
      routerProvider.overrideWith((ref) {
        final currentAuthState = ref.watch(authProvider);
        final hasAccess = currentAuthState is Authenticated ||
            currentAuthState is NoAuthRequired;
        return GoRouter(
          initialLocation: initialLocation,
          redirect: (context, state) {
            const publicRoutes = {'/', '/login', '/auth/callback'};
            final isPublicRoute = publicRoutes.contains(state.matchedLocation);
            if (!hasAccess && !isPublicRoute) {
              final target = switch (currentAuthState) {
                Unauthenticated(
                  reason: UnauthenticatedReason.explicitSignOut,
                ) =>
                  '/',
                _ => '/login',
              };
              return target;
            }
            if (hasAccess && isPublicRoute) return '/rooms';
            return null;
          },
          routes: [
            GoRoute(
              path: '/login',
              name: 'login',
              builder: (_, __) => const LoginScreen(),
            ),
            GoRoute(
              path: '/',
              name: 'home',
              builder: (_, __) => const Scaffold(body: HomeScreen()),
            ),
            GoRoute(
              path: '/rooms',
              name: 'rooms',
              builder: (_, __) => const Scaffold(body: RoomsScreen()),
            ),
            GoRoute(
              path: '/rooms/:roomId',
              name: 'room',
              builder: (context, state) {
                final roomId = state.pathParameters['roomId']!;
                final threadId = state.uri.queryParameters['thread'];
                return RoomScreen(roomId: roomId, initialThreadId: threadId);
              },
            ),
            GoRoute(
              path: '/rooms/:roomId/quiz/:quizId',
              name: 'quiz',
              builder: (context, state) {
                final roomId = state.pathParameters['roomId']!;
                final quizId = state.pathParameters['quizId']!;
                return QuizScreen(roomId: roomId, quizId: quizId);
              },
            ),
            GoRoute(
              path: '/rooms/:roomId/thread/:threadId',
              name: 'thread-redirect',
              redirect: (context, state) {
                final roomId = state.pathParameters['roomId']!;
                final threadId = state.pathParameters['threadId']!;
                return '/rooms/$roomId?thread=$threadId';
              },
            ),
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (_, __) => const Scaffold(body: SettingsScreen()),
            ),
          ],
          errorBuilder: (context, state) => Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text('Page not found: ${state.uri}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Go Home'),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
      ...overrides,
    ].cast(),
    child: Consumer(
      builder: (context, ref, _) {
        final router = ref.watch(routerProvider);
        return MaterialApp.router(
          theme: testThemeData,
          routerConfig: router,
        );
      },
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppRouter', () {
    testWidgets('redirects authenticated users from / to /rooms', (
      tester,
    ) async {
      await tester.pumpWidget(createRouterApp());
      await tester.pumpAndSettle();
      expect(find.byType(RoomsScreen), findsOneWidget);
    });

    testWidgets('redirects authenticated users from /login to /rooms', (
      tester,
    ) async {
      await tester.pumpWidget(createRouterAppAt('/login'));
      await tester.pumpAndSettle();
      expect(find.byType(RoomsScreen), findsOneWidget);
    });

    testWidgets('redirects authenticated users from /auth/callback to /rooms', (
      tester,
    ) async {
      await tester.pumpWidget(createRouterAppAt('/auth/callback'));
      await tester.pumpAndSettle();
      expect(find.byType(RoomsScreen), findsOneWidget);
    });

    testWidgets('shows home when unauthenticated at /', (tester) async {
      await tester.pumpWidget(createRouterApp(authenticated: false));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('redirects to login when accessing protected route', (
      tester,
    ) async {
      await tester.pumpWidget(
        createRouterAppAt('/rooms', authenticated: false),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('allows access to protected routes when NoAuthRequired', (
      tester,
    ) async {
      await tester.pumpWidget(
        createRouterAppAt(
          '/rooms',
          authenticated: false,
          noAuthMode: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RoomsScreen), findsOneWidget);
    });

    testWidgets('redirects NoAuthRequired users from / to /rooms', (
      tester,
    ) async {
      await tester.pumpWidget(
        createRouterApp(authenticated: false, noAuthMode: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RoomsScreen), findsOneWidget);
    });

    testWidgets('navigates to rooms screen', (tester) async {
      await tester.pumpWidget(createRouterAppAt('/rooms'));
      await tester.pumpAndSettle();
      expect(find.byType(RoomsScreen), findsOneWidget);
    });

    testWidgets('navigates to room screen with roomId', (tester) async {
      await tester.pumpWidget(
        createRouterAppAt(
          '/rooms/general',
          overrides: roomScreenOverrides('general'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RoomScreen), findsOneWidget);
    });

    testWidgets('redirects old thread URL to query param format', (
      tester,
    ) async {
      await tester.pumpWidget(
        createRouterAppAt(
          '/rooms/general/thread/thread-1',
          overrides: roomScreenOverrides('general'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RoomScreen), findsOneWidget);
    });

    testWidgets('passes thread query param to RoomScreen', (tester) async {
      await tester.pumpWidget(
        createRouterAppAt(
          '/rooms/general?thread=thread-123',
          overrides: roomScreenOverrides('general'),
        ),
      );
      await tester.pumpAndSettle();
      final roomScreen = tester.widget<RoomScreen>(find.byType(RoomScreen));
      expect(roomScreen.initialThreadId, equals('thread-123'));
    });

    testWidgets('RoomScreen receives null when no thread query param', (
      tester,
    ) async {
      await tester.pumpWidget(
        createRouterAppAt(
          '/rooms/general',
          overrides: roomScreenOverrides('general'),
        ),
      );
      await tester.pumpAndSettle();
      final roomScreen = tester.widget<RoomScreen>(find.byType(RoomScreen));
      expect(roomScreen.initialThreadId, isNull);
    });

    testWidgets('navigates to settings screen', (tester) async {
      await tester.pumpWidget(createRouterAppAt('/settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('shows error page for unknown route', (tester) async {
      await tester.pumpWidget(createRouterAppAt('/unknown-route'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Page not found'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('error page has go home button', (tester) async {
      await tester.pumpWidget(createRouterAppAt('/invalid'));
      await tester.pumpAndSettle();

      expect(find.text('Go Home'), findsOneWidget);

      await tester.tap(find.text('Go Home'));
      await tester.pumpAndSettle();

      // Authenticated users get redirected from / to /rooms
      expect(find.byType(RoomsScreen), findsOneWidget);
    });
  });

  group('Auth state changes', () {
    testWidgets('session expiry redirects to /login', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(const SoliplexConfig()),
          authProvider.overrideWith(
            () => _ControllableAuthNotifier(_createAuthenticatedState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(
                theme: testThemeData,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      container.read(routerProvider).go('/rooms');
      await tester.pumpAndSettle();

      expect(find.byType(RoomsScreen), findsOneWidget);

      // Session expiry uses default reason: sessionExpired -> /login
      (container.read(authProvider.notifier) as _ControllableAuthNotifier)
          .setUnauthenticated();
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('explicit sign-out redirects to home', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(const SoliplexConfig()),
          authProvider.overrideWith(
            () => _ControllableAuthNotifier(_createAuthenticatedState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(
                theme: testThemeData,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      container.read(routerProvider).go('/rooms');
      await tester.pumpAndSettle();

      expect(find.byType(RoomsScreen), findsOneWidget);

      // Explicit sign-out → home (to choose different backend)
      await (container.read(authProvider.notifier) as _ControllableAuthNotifier)
          .signOut();
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('token refresh preserves navigation location', (tester) async {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(const SoliplexConfig()),
          authProvider.overrideWith(
            () => _ControllableAuthNotifier(_createAuthenticatedState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(
                theme: testThemeData,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      container.read(routerProvider).go('/rooms');
      await tester.pumpAndSettle();

      expect(find.byType(RoomsScreen), findsOneWidget);

      (container.read(authProvider.notifier) as _ControllableAuthNotifier)
          .refreshTokens();
      await tester.pumpAndSettle();

      expect(find.byType(RoomsScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });
  });

  group('OAuth callback handling', () {
    testWidgets('no OAuth redirect when callback params absent', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(const SoliplexConfig()),
          capturedCallbackParamsProvider.overrideWithValue(
            const NoCallbackParams(),
          ),
          authProvider.overrideWith(
            () => _MockAuthNotifier(const Unauthenticated()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(
                theme: testThemeData,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should navigate to home screen (public route)
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(AuthCallbackScreen), findsNothing);
    });
  });

  group('Redirect logic edge cases', () {
    testWidgets('unauthenticated user at /settings redirects to /login', (
      tester,
    ) async {
      await tester.pumpWidget(
        createRouterAppAt('/settings', authenticated: false),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('NoAuthRequired user at /login redirects to /rooms', (
      tester,
    ) async {
      await tester.pumpWidget(
        createRouterAppAt(
          '/login',
          authenticated: false,
          noAuthMode: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RoomsScreen), findsOneWidget);
    });

    testWidgets('multiple rapid auth state changes preserve navigation', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          packageInfoProvider.overrideWithValue(testPackageInfo),
          shellConfigProvider.overrideWithValue(const SoliplexConfig()),
          backendVersionInfoProvider.overrideWithValue(
            const AsyncValue.data(testBackendVersionInfo),
          ),
          authProvider.overrideWith(
            () => _ControllableAuthNotifier(_createAuthenticatedState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(
                theme: testThemeData,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to settings
      container.read(routerProvider).go('/settings');
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      // Rapid token refreshes (simulating background refresh)
      (container.read(authProvider.notifier) as _ControllableAuthNotifier)
        ..refreshTokens()
        ..refreshTokens()
        ..refreshTokens();
      await tester.pumpAndSettle();

      // Should still be on settings screen
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  group('Error boundary', () {
    testWidgets('error page shows error message with route', (tester) async {
      await tester.pumpWidget(createRouterAppAt('/completely-invalid-path'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Page not found'), findsOneWidget);
      expect(find.textContaining('/completely-invalid-path'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('error page button navigates authenticated user to /rooms', (
      tester,
    ) async {
      await tester.pumpWidget(createRouterAppAt('/invalid-route'));
      await tester.pumpAndSettle();

      // Error page should be showing
      expect(find.text('Go Home'), findsOneWidget);

      // Tap "Go Home" button
      await tester.tap(find.text('Go Home'));
      await tester.pumpAndSettle();

      // Authenticated users redirect from / to /rooms
      expect(find.byType(RoomsScreen), findsOneWidget);
      expect(find.textContaining('Page not found'), findsNothing);
    });

    testWidgets('error page go home navigates to fallback route', (
      tester,
    ) async {
      // Setup: showHomeRoute: false, trigger error page
      final container = ProviderContainer(
        overrides: [
          packageInfoProvider.overrideWithValue(testPackageInfo),
          shellConfigProvider.overrideWithValue(
            const SoliplexConfig(
              routes: RouteConfig(
                showHomeRoute: false,
                initialRoute: '/rooms',
              ),
            ),
          ),
          authProvider.overrideWith(
            () => _MockAuthNotifier(_createAuthenticatedState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(
                theme: testThemeData,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to invalid route to trigger error page
      container.read(routerProvider).go('/invalid-route');
      await tester.pumpAndSettle();

      // Error page should be showing
      expect(find.text('Go Home'), findsOneWidget);

      // Action: Tap "Go home" button
      await tester.tap(find.text('Go Home'));
      await tester.pumpAndSettle();

      // Expect: Navigates to /rooms (not /) since showHomeRoute is false
      expect(find.byType(RoomsScreen), findsOneWidget);
      expect(find.textContaining('Page not found'), findsNothing);
    });
  });

  group('Route visibility helpers', () {
    test('isRouteVisible returns true for / when showHomeRoute is true', () {
      const features = Features();
      const routes = RouteConfig(); // showHomeRoute defaults to true
      expect(isRouteVisible('/', features, routes), isTrue);
    });

    test('isRouteVisible returns false for / when showHomeRoute is false', () {
      const features = Features();
      // Must set initialRoute to /rooms since / is hidden
      const routes = RouteConfig(
        showHomeRoute: false,
        initialRoute: '/rooms',
      );
      expect(isRouteVisible('/', features, routes), isFalse);
    });

    test('isRouteVisible returns true for /rooms when showRoomsRoute is true',
        () {
      const features = Features();
      const routes = RouteConfig(); // showRoomsRoute defaults to true
      expect(isRouteVisible('/rooms', features, routes), isTrue);
    });

    test('isRouteVisible handles /rooms/:roomId paths', () {
      const features = Features();
      const routes = RouteConfig(); // showRoomsRoute defaults to true
      expect(isRouteVisible('/rooms/abc-123', features, routes), isTrue);
    });

    test(
        'isRouteVisible returns true for /settings when enableSettings is true',
        () {
      const features = Features();
      const routes = RouteConfig();
      expect(isRouteVisible('/settings', features, routes), isTrue);
    });

    test(
        'isRouteVisible returns false for /settings when enableSettings is false',
        () {
      const features = Features(enableSettings: false);
      const routes = RouteConfig();
      expect(isRouteVisible('/settings', features, routes), isFalse);
    });

    test('isRouteVisible for /settings depends only on enableSettings', () {
      // enableSettings true - visible
      expect(
        isRouteVisible(
          '/settings',
          const Features(),
          const RouteConfig(),
        ),
        isTrue,
      );
      // enableSettings false - hidden
      expect(
        isRouteVisible(
          '/settings',
          const Features(enableSettings: false),
          const RouteConfig(),
        ),
        isFalse,
      );
    });

    test('getDefaultAuthenticatedRoute returns initialRoute when visible', () {
      const features = Features();
      const routes = RouteConfig(initialRoute: '/rooms');
      expect(getDefaultAuthenticatedRoute(features, routes), equals('/rooms'));
    });

    test('getDefaultAuthenticatedRoute falls back when initialRoute hidden',
        () {
      const features = Features(enableSettings: false);
      const routes = RouteConfig(initialRoute: '/settings');
      expect(getDefaultAuthenticatedRoute(features, routes), equals('/rooms'));
    });

    test('getDefaultAuthenticatedRoute falls back to / when rooms disabled',
        () {
      const features = Features();
      const routes = RouteConfig(showRoomsRoute: false);
      expect(getDefaultAuthenticatedRoute(features, routes), equals('/'));
    });

    test('isRouteVisible handles routes with query parameters', () {
      const features = Features();
      const routes = RouteConfig();
      // /settings with query params should still match /settings
      expect(isRouteVisible('/settings?theme=dark', features, routes), isTrue);
      // / with query params (OAuth callback scenarios)
      expect(isRouteVisible('/?code=abc', features, routes), isTrue);
      // /rooms with query params
      expect(isRouteVisible('/rooms?filter=active', features, routes), isTrue);
    });

    test('isRouteVisible handles deep rooms paths', () {
      const features = Features();
      const routes = RouteConfig();
      // /rooms/:roomId/quiz/:quizId visible when quizzes enabled (defaults)
      expect(isRouteVisible('/rooms/abc/quiz/123', features, routes), isTrue);
      // /rooms/:roomId with query params
      expect(
        isRouteVisible('/rooms/abc?thread=xyz', features, routes),
        isTrue,
      );
    });

    test('isRouteVisible returns false for quiz routes when quizzes disabled',
        () {
      // Quiz route hidden when enableQuizzes is false
      expect(
        isRouteVisible(
          '/rooms/abc/quiz/123',
          const Features(enableQuizzes: false),
          const RouteConfig(),
        ),
        isFalse,
      );
      // Non-quiz room paths still work when quizzes disabled
      expect(
        isRouteVisible(
          '/rooms/abc',
          const Features(enableQuizzes: false),
          const RouteConfig(),
        ),
        isTrue,
      );
    });

    test('isRouteVisible returns false for unknown routes', () {
      const features = Features();
      const routes = RouteConfig();
      // Unknown top-level route
      expect(isRouteVisible('/unknown', features, routes), isFalse);
      // Unknown nested route
      expect(isRouteVisible('/foo/bar', features, routes), isFalse);
    });

    test('isRouteVisible rejects invalid rooms sub-paths', () {
      const features = Features();
      const routes = RouteConfig();
      // Invalid: 3 segments without 'quiz' at [2]
      expect(isRouteVisible('/rooms/abc/invalid', features, routes), isFalse);
      // Invalid: extra garbage segments
      expect(
        isRouteVisible('/rooms/123/invalid/garbage', features, routes),
        isFalse,
      );
      // Invalid: 5+ segments
      expect(
        isRouteVisible('/rooms/abc/quiz/123/extra', features, routes),
        isFalse,
      );
      // Valid patterns still work
      expect(isRouteVisible('/rooms', features, routes), isTrue);
      expect(isRouteVisible('/rooms/abc', features, routes), isTrue);
      expect(isRouteVisible('/rooms/abc/quiz/123', features, routes), isTrue);
    });

    test('isRouteVisible handles trailing slashes correctly', () {
      const features = Features();
      const routes = RouteConfig();
      // Uri.parse handles trailing slashes by including them in pathSegments
      // But /rooms/ would have ['rooms', ''] which is 2 segments
      // This should be handled by the caller normalizing paths
      expect(isRouteVisible('/rooms', features, routes), isTrue);
      expect(isRouteVisible('/settings', features, routes), isTrue);
    });

    test('isRouteVisible returns false for malformed URIs', () {
      const features = Features();
      const routes = RouteConfig();
      // Uri.tryParse returns null for malformed URIs - should return false
      // This tests the defensive behavior in isRouteVisible
      expect(isRouteVisible('::notavaliduri::', features, routes), isFalse);
    });
  });

  group('Redirect with disabled routes', () {
    testWidgets('authenticated user redirects to / when rooms disabled', (
      tester,
    ) async {
      // Setup: showRoomsRoute: false, showHomeRoute: true
      final container = ProviderContainer(
        overrides: [
          packageInfoProvider.overrideWithValue(testPackageInfo),
          shellConfigProvider.overrideWithValue(
            const SoliplexConfig(
              routes: RouteConfig(showRoomsRoute: false),
            ),
          ),
          authProvider.overrideWith(
            () => _MockAuthNotifier(_createAuthenticatedState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(
                theme: testThemeData,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expect: Redirects to / (not /rooms)
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(RoomsScreen), findsNothing);
    });

    testWidgets('authenticated user redirects to /rooms when home disabled', (
      tester,
    ) async {
      // Setup: showHomeRoute: false, showRoomsRoute: true
      final container = ProviderContainer(
        overrides: [
          packageInfoProvider.overrideWithValue(testPackageInfo),
          shellConfigProvider.overrideWithValue(
            const SoliplexConfig(
              routes: RouteConfig(
                showHomeRoute: false,
                initialRoute: '/rooms',
              ),
            ),
          ),
          authProvider.overrideWith(
            () => _MockAuthNotifier(_createAuthenticatedState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(
                theme: testThemeData,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expect: Redirects to /rooms
      expect(find.byType(RoomsScreen), findsOneWidget);
    });

    testWidgets('sign-out redirects to /login regardless of config', (
      tester,
    ) async {
      // Setup: showHomeRoute: false - verify sign-out goes to /login not /
      final container = ProviderContainer(
        overrides: [
          packageInfoProvider.overrideWithValue(testPackageInfo),
          shellConfigProvider.overrideWithValue(
            const SoliplexConfig(
              routes: RouteConfig(
                showHomeRoute: false,
                initialRoute: '/rooms',
              ),
            ),
          ),
          authProvider.overrideWith(
            () => _ControllableAuthNotifier(_createAuthenticatedState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(
                theme: testThemeData,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RoomsScreen), findsOneWidget);

      // Action: Sign out
      await (container.read(authProvider.notifier) as _ControllableAuthNotifier)
          .signOut();
      await tester.pumpAndSettle();

      // Expect: Redirects to /login (not / which would crash)
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('no redirect loop when already on target route', (
      tester,
    ) async {
      // Setup: showRoomsRoute: false, showHomeRoute: true, authenticated on /
      // The / route is a public route, but authenticated users should stay
      // if it's their default route
      final container = ProviderContainer(
        overrides: [
          packageInfoProvider.overrideWithValue(testPackageInfo),
          shellConfigProvider.overrideWithValue(
            const SoliplexConfig(
              routes: RouteConfig(showRoomsRoute: false),
            ),
          ),
          authProvider.overrideWith(
            () => _MockAuthNotifier(_createAuthenticatedState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(
                theme: testThemeData,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should land on / without redirect loop
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('initialRoute validated - falls back when target disabled', (
      tester,
    ) async {
      // Setup: initialRoute: '/settings', enableSettings: false
      final container = ProviderContainer(
        overrides: [
          packageInfoProvider.overrideWithValue(testPackageInfo),
          shellConfigProvider.overrideWithValue(
            const SoliplexConfig(
              features: Features(enableSettings: false),
              routes: RouteConfig(initialRoute: '/settings'),
            ),
          ),
          authProvider.overrideWith(
            () => _MockAuthNotifier(_createAuthenticatedState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(
                theme: testThemeData,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expect: initialLocation is /rooms (fallback), not /settings
      expect(find.byType(RoomsScreen), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);
    });

    testWidgets('initialRoute used when target enabled', (tester) async {
      // Setup: initialRoute: '/settings', enableSettings: true (defaults)
      final container = ProviderContainer(
        overrides: [
          packageInfoProvider.overrideWithValue(testPackageInfo),
          shellConfigProvider.overrideWithValue(
            const SoliplexConfig(
              routes: RouteConfig(initialRoute: '/settings'),
            ),
          ),
          backendVersionInfoProvider.overrideWithValue(
            const AsyncValue.data(testBackendVersionInfo),
          ),
          authProvider.overrideWith(
            () => _MockAuthNotifier(_createAuthenticatedState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(
                theme: testThemeData,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expect: initialLocation is /settings
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  group('Whitelabel Configuration Integration', () {
    testWidgets('app boots with showRoomsRoute: false', (tester) async {
      // Config: RouteConfig(showRoomsRoute: false, showHomeRoute: true)
      final container = ProviderContainer(
        overrides: [
          packageInfoProvider.overrideWithValue(testPackageInfo),
          shellConfigProvider.overrideWithValue(
            const SoliplexConfig(
              routes: RouteConfig(showRoomsRoute: false),
            ),
          ),
          authProvider.overrideWith(
            () => _MockAuthNotifier(_createAuthenticatedState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(
                theme: testThemeData,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify: App boots without crash, lands on /
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('app boots with showHomeRoute: false', (tester) async {
      // Config: RouteConfig(showHomeRoute: false, showRoomsRoute: true)
      final container = ProviderContainer(
        overrides: [
          packageInfoProvider.overrideWithValue(testPackageInfo),
          shellConfigProvider.overrideWithValue(
            const SoliplexConfig(
              routes: RouteConfig(
                showHomeRoute: false,
                initialRoute: '/rooms',
              ),
            ),
          ),
          authProvider.overrideWith(
            () => _MockAuthNotifier(_createAuthenticatedState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(routerProvider);
              return MaterialApp.router(
                theme: testThemeData,
                routerConfig: router,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify: App boots without crash, lands on /rooms
      expect(find.byType(RoomsScreen), findsOneWidget);
    });
  });
}

class _ControllableAuthNotifier extends AuthNotifier {
  _ControllableAuthNotifier(this._initialState);
  final AuthState _initialState;

  @override
  AuthState build() => _initialState;

  void setUnauthenticated() {
    state = const Unauthenticated();
  }

  @override
  Future<void> signOut() async {
    state = const Unauthenticated(
      reason: UnauthenticatedReason.explicitSignOut,
    );
  }

  void refreshTokens() {
    final current = state;
    if (current is Authenticated) {
      state = Authenticated(
        accessToken: 'refreshed-token-${DateTime.now().millisecondsSinceEpoch}',
        refreshToken: current.refreshToken,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        issuerId: current.issuerId,
        issuerDiscoveryUrl: current.issuerDiscoveryUrl,
        clientId: current.clientId,
        idToken: current.idToken,
      );
    }
  }
}
