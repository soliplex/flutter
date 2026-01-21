import 'package:meta/meta.dart';

/// Configuration for route visibility and behavior.
///
/// Allows white-label apps to hide built-in routes or specify a custom
/// initial route.
@immutable
class RouteConfig {
  /// Creates a route configuration with all routes visible by default.
  const RouteConfig({
    this.showHomeRoute = true,
    this.showRoomsRoute = true,
    this.initialRoute = '/',
    this.authenticatedLandingRoute = '/rooms',
  }) : assert(
          showHomeRoute || showRoomsRoute,
          'At least one main route (home or rooms) must be enabled',
        );

  /// Whether the home route ('/') is accessible.
  final bool showHomeRoute;

  /// Whether the rooms route ('/rooms') is accessible.
  final bool showRoomsRoute;

  /// The initial route when app launches (before authentication).
  ///
  /// Defaults to '/' (home) where users configure the backend URL.
  /// White-label apps may set this to '/rooms' to skip the home screen.
  final String initialRoute;

  /// Where authenticated users land after login or when returning to the app.
  ///
  /// Defaults to '/rooms'. This is separate from [initialRoute] because:
  /// - [initialRoute]: Where unauthenticated users start (typically home)
  /// - [authenticatedLandingRoute]: Where authenticated users belong
  final String authenticatedLandingRoute;

  /// Creates a copy with the specified fields replaced.
  RouteConfig copyWith({
    bool? showHomeRoute,
    bool? showRoomsRoute,
    String? initialRoute,
    String? authenticatedLandingRoute,
  }) {
    return RouteConfig(
      showHomeRoute: showHomeRoute ?? this.showHomeRoute,
      showRoomsRoute: showRoomsRoute ?? this.showRoomsRoute,
      initialRoute: initialRoute ?? this.initialRoute,
      authenticatedLandingRoute:
          authenticatedLandingRoute ?? this.authenticatedLandingRoute,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteConfig &&
          runtimeType == other.runtimeType &&
          showHomeRoute == other.showHomeRoute &&
          showRoomsRoute == other.showRoomsRoute &&
          initialRoute == other.initialRoute &&
          authenticatedLandingRoute == other.authenticatedLandingRoute;

  @override
  int get hashCode => Object.hash(
        showHomeRoute,
        showRoomsRoute,
        initialRoute,
        authenticatedLandingRoute,
      );

  @override
  String toString() => 'RouteConfig('
      'showHomeRoute: $showHomeRoute, '
      'showRoomsRoute: $showRoomsRoute, '
      'initialRoute: $initialRoute, '
      'authenticatedLandingRoute: $authenticatedLandingRoute)';
}
