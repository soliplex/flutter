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
    this.showSettingsRoute = true,
    this.showQuizRoute = true,
    this.initialRoute = '/',
  });

  /// Whether the home route ('/') is accessible.
  final bool showHomeRoute;

  /// Whether the rooms route ('/rooms') is accessible.
  final bool showRoomsRoute;

  /// Whether the settings route ('/settings') is accessible.
  final bool showSettingsRoute;

  /// Whether quiz routes ('/rooms/:roomId/quiz/:quizId') are accessible.
  final bool showQuizRoute;

  /// The initial route to navigate to on app launch.
  ///
  /// Defaults to '/' (home). White-label apps may set this to '/rooms'
  /// or a specific room path.
  final String initialRoute;

  /// Creates a copy with the specified fields replaced.
  RouteConfig copyWith({
    bool? showHomeRoute,
    bool? showRoomsRoute,
    bool? showSettingsRoute,
    bool? showQuizRoute,
    String? initialRoute,
  }) {
    return RouteConfig(
      showHomeRoute: showHomeRoute ?? this.showHomeRoute,
      showRoomsRoute: showRoomsRoute ?? this.showRoomsRoute,
      showSettingsRoute: showSettingsRoute ?? this.showSettingsRoute,
      showQuizRoute: showQuizRoute ?? this.showQuizRoute,
      initialRoute: initialRoute ?? this.initialRoute,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteConfig &&
          runtimeType == other.runtimeType &&
          showHomeRoute == other.showHomeRoute &&
          showRoomsRoute == other.showRoomsRoute &&
          showSettingsRoute == other.showSettingsRoute &&
          showQuizRoute == other.showQuizRoute &&
          initialRoute == other.initialRoute;

  @override
  int get hashCode => Object.hash(
        showHomeRoute,
        showRoomsRoute,
        showSettingsRoute,
        showQuizRoute,
        initialRoute,
      );

  @override
  String toString() => 'RouteConfig('
      'showHomeRoute: $showHomeRoute, '
      'showRoomsRoute: $showRoomsRoute, '
      'showSettingsRoute: $showSettingsRoute, '
      'showQuizRoute: $showQuizRoute, '
      'initialRoute: $initialRoute)';
}
