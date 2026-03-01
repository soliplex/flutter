import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/auth/web_auth_callback.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/models/features.dart';
import 'package:soliplex_frontend/core/models/route_config.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
import 'package:soliplex_frontend/features/auth/auth_callback_screen.dart';
// TEMPORARY: Debug agent screen — remove after F1 validation.
import 'package:soliplex_frontend/features/debug/debug_agent_screen.dart';
import 'package:soliplex_frontend/features/demos/debate_arena/debate_arena_screen.dart';
import 'package:soliplex_frontend/features/demos/pipeline_visualizer/pipeline_screen.dart';
import 'package:soliplex_frontend/features/home/home_screen.dart';
import 'package:soliplex_frontend/features/inspector/network_inspector_screen.dart';
import 'package:soliplex_frontend/features/log_viewer/log_viewer_screen.dart';
import 'package:soliplex_frontend/features/login/login_screen.dart';
import 'package:soliplex_frontend/features/quiz/quiz_screen.dart';
import 'package:soliplex_frontend/features/room/room_screen.dart';
import 'package:soliplex_frontend/features/room/widgets/room_info_screen.dart';
import 'package:soliplex_frontend/features/rooms/rooms_screen.dart';
import 'package:soliplex_frontend/features/settings/backend_versions_screen.dart';
import 'package:soliplex_frontend/features/settings/settings_screen.dart';
import 'package:soliplex_frontend/features/settings/telemetry_screen.dart';
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

/// Back button that navigates to settings.
class _BackToSettingsButton extends StatelessWidget {
  const _BackToSettingsButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => context.go('/settings'),
      tooltip: 'Back to settings',
    );
  }
}

/// Creates an AppShell with the given configuration.
AppShell _staticShell({
  required Widget title,
  required Widget body,
  Widget? leading,
  List<Widget> actions = const [],
}) {
  return AppShell(
    config: ShellConfig(
      title: title,
      leading: leading,
      actions: actions,
    ),
    body: body,
  );
}

/// Creates a NoTransitionPage with AppShell for static screens.
NoTransitionPage<void> _staticPage({
  required Widget title,
  required Widget body,
  Widget? leading,
  List<Widget> actions = const [],
}) {
  return NoTransitionPage(
    child: _staticShell(
      title: title,
      body: body,
      leading: leading,
      actions: actions,
    ),
  );
}

/// Checks if a route is visible given current config.
///
/// Handles routes with query parameters and trailing slashes correctly by
/// parsing the URI and using pathSegments for consistent matching.
/// Also checks quiz-specific routes when relevant feature flags are set.
///
/// Returns false for malformed URIs or invalid path structures (safe fallback).
/// Only validates known route patterns - unknown segments return false.
@visibleForTesting
bool isRouteVisible(String route, Features features, RouteConfig routes) {
  final uri = Uri.tryParse(route);
  if (uri == null) return false; // Malformed URI - safe fallback

  final segments = uri.pathSegments;

  // Root path (empty segments means '/')
  if (segments.isEmpty) return routes.showHomeRoute;

  // Settings route - exactly one segment
  if (segments.length == 1 && segments.first == 'settings') {
    return features.enableSettings;
  }

  // Rooms routes with strict segment validation:
  // - /rooms (1 segment)
  // - /rooms/:roomId (2 segments)
  // - /rooms/:roomId/quiz/:quizId (4 segments, segments[2] == 'quiz')
  if (segments.first == 'rooms') {
    if (!routes.showRoomsRoute) return false;

    // /rooms - exactly 1 segment
    if (segments.length == 1) return true;

    // /rooms/:roomId - exactly 2 segments
    if (segments.length == 2) return true;

    // /rooms/:roomId/info - exactly 3 segments with 'info' at [2]
    if (segments.length == 3 && segments[2] == 'info') return true;

    // /rooms/:roomId/quiz/:quizId - exactly 4 segments with 'quiz' at [2]
    if (segments.length == 4 && segments[2] == 'quiz') {
      return features.enableQuizzes;
    }

    // Any other structure under /rooms is invalid
    return false;
  }

  return false;
}

/// Returns the route where authenticated users should land.
///
/// Uses [RouteConfig.authenticatedLandingRoute] (defaults to '/rooms').
/// Falls back through: authenticatedLandingRoute -> /rooms -> / -> /settings.
/// If no routes are configured, returns '/login' as a safe landing.
@visibleForTesting
String getDefaultAuthenticatedRoute(Features features, RouteConfig routes) {
  final landing = routes.authenticatedLandingRoute;
  if (isRouteVisible(landing, features, routes)) return landing;

  if (routes.showRoomsRoute) return '/rooms';
  if (routes.showHomeRoute) return '/';
  if (features.enableSettings) return '/settings';

  // Fallback to /login - always exists and handles authenticated users gracefully
  // This case should rarely occur with default RouteConfig values
  return '/login';
}

/// Normalizes a path by removing trailing slashes (except for root).
///
/// Examples: '/rooms/' -> '/rooms', '/' -> '/', '/settings/' -> '/settings'
String _normalizePath(String path) {
  if (path == '/' || path.isEmpty) return '/';
  return path.endsWith('/') ? path.substring(0, path.length - 1) : path;
}

/// Routes that don't require authentication.
///
/// Home ('/') is public so users can configure the backend URL before auth.
/// When [RouteConfig.showHomeRoute] is false, the '/' route doesn't exist
/// (no fallback) - requests to '/' will hit the error page.
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
/// - `/login` - Login screen (public, authenticated users redirect to landing)
/// - `/` - Home screen (public, authenticated users redirect to landing)
/// - `/auth/callback` - OAuth callback (public, authenticated users redirect to landing)
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
  final shellConfig = ref.read(shellConfigProvider);
  final routeConfig = shellConfig.routes;
  final features = shellConfig.features;

  // Check if this is an OAuth callback (tokens in URL from backend BFF)
  final capturedParams = ref.read(capturedCallbackParamsProvider);
  final isOAuthCallback = capturedParams is WebCallbackParams;
  Loggers.router.debug('isOAuthCallback = $isOAuthCallback');

  // Use configured initial route or default to /
  final configuredInitial = routeConfig.initialRoute;
  final validatedInitial =
      isRouteVisible(configuredInitial, features, routeConfig)
          ? configuredInitial
          : getDefaultAuthenticatedRoute(features, routeConfig);
  // Route to callback screen if we have OAuth tokens to process
  final initialPath = isOAuthCallback ? '/auth/callback' : validatedInitial;
  Loggers.router.debug('Initial location: $initialPath');

  return GoRouter(
    initialLocation: initialPath, // Preserve query params for OAuth/deep links
    // Triggers redirect re-evaluation on auth transitions without
    // recreating the router.
    refreshListenable: authStatusListenable,
    redirect: (context, state) {
      // Normalize path to prevent trailing slash mismatches
      final currentPath = _normalizePath(state.uri.path);
      Loggers.router.debug('redirect called for $currentPath');
      // CRITICAL: Use ref.read() for fresh auth state, not a captured variable.
      // This ensures the redirect always sees current auth status.
      final authState = ref.read(authProvider);
      final hasAccess =
          authState is Authenticated || authState is NoAuthRequired;
      final isPublicRoute = _publicRoutes.contains(currentPath);
      Loggers.router.debug('hasAccess=$hasAccess, isPublic=$isPublicRoute');

      // Redirect based on auth state reason (Unauthenticated) or default to
      // /login (AuthLoading). Public routes are exempt.
      if (!hasAccess && !isPublicRoute) {
        // Explicit sign-out → home (to choose different backend), if available.
        // Falls back to /login when home route is disabled (whitelabel config).
        final isExplicitSignOut = authState is Unauthenticated &&
            authState.reason == UnauthenticatedReason.explicitSignOut;
        if (isExplicitSignOut) {
          Loggers.router.info('Explicit sign-out detected');
        }
        final target =
            isExplicitSignOut && routeConfig.showHomeRoute ? '/' : '/login';
        Loggers.router.debug('redirecting to $target');
        return target;
      }

      // Public routes are for guests only - redirect to rooms if authenticated
      if (hasAccess && isPublicRoute) {
        final target = getDefaultAuthenticatedRoute(features, routeConfig);
        if (target != currentPath) {
          Loggers.router.debug('redirecting to $target');
          return target;
        }
      }

      Loggers.router.debug('no redirect');
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
      if (routeConfig.showHomeRoute)
        GoRoute(
          path: '/',
          name: 'home',
          pageBuilder: (context, state) {
            return _staticPage(
              title: Text(shellConfig.appName),
              body: const HomeScreen(),
              actions: [if (features.enableSettings) const _SettingsButton()],
            );
          },
        ),
      if (routeConfig.showRoomsRoute)
        GoRoute(
          path: '/rooms',
          name: 'rooms',
          pageBuilder: (context, state) => _staticPage(
            title: const Text('Rooms'),
            body: const RoomsScreen(),
            actions: [if (features.enableSettings) const _SettingsButton()],
          ),
        ),
      if (routeConfig.showRoomsRoute)
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
      if (routeConfig.showRoomsRoute)
        GoRoute(
          path: '/rooms/:roomId/info',
          name: 'room-info',
          pageBuilder: (context, state) {
            final roomId = state.pathParameters['roomId']!;
            return NoTransitionPage(
              child: RoomInfoScreen(roomId: roomId),
            );
          },
        ),
      if (features.enableQuizzes)
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
      if (routeConfig.showRoomsRoute)
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
      // --- TEMPORARY: Debug agent run screen — remove after F1 validation ---
      GoRoute(
        path: '/debug/agent',
        name: 'debug-agent',
        pageBuilder: (context, state) => _staticPage(
          title: const Text('DEBUG: Agent Run'),
          leading: const _BackToSettingsButton(),
          body: const DebugAgentScreen(),
        ),
      ),
      // --- END TEMPORARY ---
      GoRoute(
        path: '/demos/debate',
        name: 'debate-arena',
        pageBuilder: (context, state) => _staticPage(
          title: const Text('Debate Arena'),
          leading: const _BackToSettingsButton(),
          body: const DebateArenaScreen(),
          actions: [
            if (features.enableSettings) const _SettingsButton(),
          ],
        ),
      ),
      GoRoute(
        path: '/demos/pipeline',
        name: 'pipeline-visualizer',
        pageBuilder: (context, state) => _staticPage(
          title: const Text('Pipeline Visualizer'),
          leading: const _BackToSettingsButton(),
          body: const PipelineScreen(),
          actions: [
            if (features.enableSettings) const _SettingsButton(),
          ],
        ),
      ),
      if (features.enableSettings)
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
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: BackendVersionsScreen()),
            ),
            GoRoute(
              path: 'network',
              name: 'network-inspector',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: NetworkInspectorScreen(),
              ),
            ),
            GoRoute(
              path: 'logs',
              name: 'log-viewer',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: LogViewerScreen(),
              ),
            ),
            GoRoute(
              path: 'telemetry',
              name: 'telemetry',
              pageBuilder: (context, state) => _staticPage(
                title: const Text('Telemetry'),
                body: const TelemetryScreen(),
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
              onPressed: () => context.go(
                getDefaultAuthenticatedRoute(features, routeConfig),
              ),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
