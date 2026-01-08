import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_frontend/core/auth/auth_notifier.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/core/router/app_router.dart';
import 'package:soliplex_frontend/features/home/home_screen.dart';
import 'package:soliplex_frontend/features/login/login_screen.dart';
import 'package:soliplex_frontend/features/room/room_screen.dart';
import 'package:soliplex_frontend/features/rooms/rooms_screen.dart';
import 'package:soliplex_frontend/features/settings/settings_screen.dart';

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
            if (!hasAccess && !isPublicRoute) return '/login';
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
        return MaterialApp.router(routerConfig: router);
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
    testWidgets('logout from deep navigation redirects to /login', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
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
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      container.read(routerProvider).go('/rooms');
      await tester.pumpAndSettle();

      expect(find.byType(RoomsScreen), findsOneWidget);

      (container.read(authProvider.notifier) as _ControllableAuthNotifier)
          .setUnauthenticated();
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('token refresh preserves navigation location', (tester) async {
      final container = ProviderContainer(
        overrides: [
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
              return MaterialApp.router(routerConfig: router);
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
}

class _ControllableAuthNotifier extends AuthNotifier {
  _ControllableAuthNotifier(this._initialState);
  final AuthState _initialState;

  @override
  AuthState build() => _initialState;

  void setUnauthenticated() {
    state = const Unauthenticated();
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
