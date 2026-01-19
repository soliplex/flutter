import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/auth/web_auth_callback.dart';
import 'package:soliplex_frontend/core/build_config.dart';
import 'package:soliplex_frontend/features/auth/auth_callback_screen.dart';
import 'package:soliplex_frontend/features/home/home_screen.dart';
import 'package:soliplex_frontend/features/login/login_screen.dart';
import 'package:soliplex_frontend/features/quiz/quiz_screen.dart';
import 'package:soliplex_frontend/features/room/room_screen.dart';
import 'package:soliplex_frontend/features/rooms/rooms_screen.dart';
import 'package:soliplex_frontend/features/settings/backend_versions_screen.dart';
import 'package:soliplex_frontend/features/settings/settings_screen.dart';
import 'package:soliplex_frontend/shared/widgets/app_shell.dart';
import 'package:soliplex_frontend/shared/widgets/shell_config.dart';

/// Settings button for AppBar actions.
///
/// Navigates to the settings screen when pressed.
class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Settings',
      child: IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () => context.push('/settings'),
        tooltip: 'Open settings',
      ),
    );
  }
}

/// Creates an AppShell with the given configuration.
AppShell _staticShell({
  required Widget title,
  required Widget body,
  List<Widget> actions = const [],
}) {
  return AppShell(
    config: ShellConfig(title: title, actions: actions),
    body: body,
  );
}

/// Creates a NoTransitionPage with AppShell for static screens.
NoTransitionPage<void> _staticPage({
  required Widget title,
  required Widget body,
  List<Widget> actions = const [],
}) {
  return NoTransitionPage(
    child: _staticShell(title: title, body: body, actions: actions),
  );
}

/// Routes that don't require authentication.
/// Home is public so users can configure the backend URL before auth.
const _publicRoutes = {'/', '/login', '/auth/callback'};

/// Application router provider.
///
/// Creates a GoRouter that redirects unauthenticated users to login.
///
/// Uses [authStatusListenableProvider] to trigger redirect re-evaluation
/// on login/logout transitions WITHOUT recreating the router. This preserves
/// navigation state during token refresh (which updates auth state but
/// shouldn't cause navigation).
///
/// Routes:
/// - `/login` - Login screen (public, authenticated users redirect to /rooms)
/// - `/` - Home screen (public, authenticated users redirect to /rooms)
/// - `/auth/callback` - OAuth callback (public, authenticated users redirect to /rooms)
/// - `/rooms` - List of rooms (requires auth)
/// - `/rooms/:roomId` - Room with thread selection (requires auth)
/// - `/rooms/:roomId/quiz/:quizId` - Quiz screen (requires auth)
/// - `/rooms/:roomId/thread/:threadId` - Redirects to query param format
/// - `/settings` - Settings screen (requires auth)
///
/// All routes use NoTransitionPage for instant navigation.
/// Static screens are wrapped in AppShell via [_staticPage].
/// RoomScreen builds its own AppShell for dynamic configuration.
final routerProvider = Provider<GoRouter>((ref) {
  // Use refreshListenable instead of ref.watch(authProvider) to avoid
  // recreating the router on every auth state change (including token refresh).
  // The listenable only fires on actual login/logout transitions.
  final authStatusListenable = ref.watch(authStatusListenableProvider);

  // Check if this is an OAuth callback (tokens in URL from backend BFF)
  final capturedParams = ref.read(capturedCallbackParamsProvider);
  final isOAuthCallback = capturedParams is WebCallbackParams;
  debugPrint('Router: isOAuthCallback = $isOAuthCallback');

  // Route to callback screen if we have OAuth tokens to process
  final initialPath = isOAuthCallback ? '/auth/callback' : '/';

  return GoRouter(
    initialLocation: initialPath.split('?').first, // Strip query params
    // Triggers redirect re-evaluation on auth transitions without
    // recreating the router.
    refreshListenable: authStatusListenable,
    redirect: (context, state) {
      debugPrint('Router: redirect called for ${state.matchedLocation}');
      // CRITICAL: Use ref.read() for fresh auth state, not a captured variable.
      // This ensures the redirect always sees current auth status.
      final authState = ref.read(authProvider);
      final hasAccess =
          authState is Authenticated || authState is NoAuthRequired;
      final isPublicRoute = _publicRoutes.contains(state.matchedLocation);
      debugPrint(
        'Router: hasAccess=$hasAccess, isPublic=$isPublicRoute',
      );

      // Redirect based on auth state reason (Unauthenticated) or default to
      // /login (AuthLoading). Public routes are exempt.
      if (!hasAccess && !isPublicRoute) {
        final target = switch (authState) {
          Unauthenticated(reason: UnauthenticatedReason.explicitSignOut) => '/',
          _ => '/login',
        };
        debugPrint('Router: redirecting to $target');
        return target;
      }

      // Public routes are for guests only - redirect to rooms if authenticated
      if (hasAccess && isPublicRoute) {
        debugPrint('Router: redirecting to /rooms');
        return '/rooms';
      }

      debugPrint('Router: no redirect');
      return null;
    },
    routes: [
      // Login uses NoTransitionPage directly (no AppShell) -
      // auth screens are intentionally chrome-less
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginScreen()),
      ),
      // OAuth callback for web BFF flow - must bypass auth guard
      GoRoute(
        path: '/auth/callback',
        name: 'auth-callback',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: AuthCallbackScreen()),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        pageBuilder: (context, state) => _staticPage(
          title: const Text(appName),
          body: const HomeScreen(),
          actions: const [_SettingsButton()],
        ),
      ),
      GoRoute(
        path: '/rooms',
        name: 'rooms',
        pageBuilder: (context, state) => _staticPage(
          title: const Text('Rooms'),
          body: const RoomsScreen(),
          actions: const [_SettingsButton()],
        ),
      ),
      GoRoute(
        path: '/rooms/:roomId',
        name: 'room',
        pageBuilder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          final threadId = state.uri.queryParameters['thread'];
          return NoTransitionPage(
            child: RoomScreen(roomId: roomId, initialThreadId: threadId),
          );
        },
      ),
      GoRoute(
        path: '/rooms/:roomId/quiz/:quizId',
        name: 'quiz',
        pageBuilder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          final quizId = state.pathParameters['quizId']!;
          return NoTransitionPage(
            child: QuizScreen(roomId: roomId, quizId: quizId),
          );
        },
      ),
      // Migration redirect: old thread URLs -> new query param format
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
        pageBuilder: (context, state) => _staticPage(
          title: const Text('Settings'),
          body: const SettingsScreen(),
        ),
        routes: [
          GoRoute(
            path: 'backend-versions',
            name: 'backend-versions',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BackendVersionsScreen(),
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => _staticShell(
      title: const Text('Error'),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(child: Icon(Icons.error_outline, size: 48)),
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
});
