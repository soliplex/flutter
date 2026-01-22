import 'package:meta/meta.dart';
import 'package:soliplex_frontend/core/models/features.dart';
import 'package:soliplex_frontend/core/models/route_config.dart';
import 'package:soliplex_frontend/core/models/theme_config.dart';

/// Root configuration for a Soliplex-based application.
///
/// This class aggregates all configuration options needed to customize
/// a white-label app built on the Soliplex shell. It includes:
/// - Branding (app name, default backend URL)
/// - Feature flags
/// - Theme configuration
/// - Route configuration
///
/// Example usage:
/// ```dart
/// final config = SoliplexConfig(
///   appName: 'MyBrand',
///   defaultBackendUrl: 'https://api.mybrand.com',
///   features: const Features(
///     enableHttpInspector: false,
///     enableQuizzes: true,
///   ),
/// );
/// ```
@immutable
class SoliplexConfig {
  /// Creates a Soliplex configuration with sensible defaults.
  const SoliplexConfig({
    this.appName = 'Soliplex',
    this.defaultBackendUrl,
    this.oauthRedirectScheme,
    this.features = const Features(),
    this.theme = const ThemeConfig(),
    this.routes = const RouteConfig(),
  });

  /// The display name of the application.
  ///
  /// Used in titles, about screens, and anywhere the app name is shown.
  final String appName;

  /// The default backend URL for API requests.
  ///
  /// When null, uses platform-specific defaults:
  /// - Native: `http://localhost:8000`
  /// - Web + localhost: `http://localhost:8000`
  /// - Web + production: same origin as client
  ///
  /// Can be overridden by the user in settings if settings are enabled.
  final String? defaultBackendUrl;

  /// OAuth redirect URI scheme for native platforms (iOS/Android).
  ///
  /// Must match the scheme registered in the shell app's platform configs:
  /// - iOS: Info.plist CFBundleURLSchemes
  /// - Android: build.gradle.kts appAuthRedirectScheme
  ///
  /// Example: `'com.mybrand.app'` results in redirect URI
  /// `'com.mybrand.app://callback'`
  ///
  /// Required for native builds. Ignored on web (uses origin-based redirect).
  final String? oauthRedirectScheme;

  /// Feature flags controlling which functionality is available.
  final Features features;

  /// Theme configuration for light and dark mode colors.
  final ThemeConfig theme;

  /// Route configuration for navigation behavior.
  final RouteConfig routes;

  /// Creates a copy with the specified fields replaced.
  SoliplexConfig copyWith({
    String? appName,
    String? defaultBackendUrl,
    String? oauthRedirectScheme,
    Features? features,
    ThemeConfig? theme,
    RouteConfig? routes,
  }) {
    return SoliplexConfig(
      appName: appName ?? this.appName,
      defaultBackendUrl: defaultBackendUrl ?? this.defaultBackendUrl,
      oauthRedirectScheme: oauthRedirectScheme ?? this.oauthRedirectScheme,
      features: features ?? this.features,
      theme: theme ?? this.theme,
      routes: routes ?? this.routes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoliplexConfig &&
          runtimeType == other.runtimeType &&
          appName == other.appName &&
          defaultBackendUrl == other.defaultBackendUrl &&
          oauthRedirectScheme == other.oauthRedirectScheme &&
          features == other.features &&
          theme == other.theme &&
          routes == other.routes;

  @override
  int get hashCode => Object.hash(
        appName,
        defaultBackendUrl,
        oauthRedirectScheme,
        features,
        theme,
        routes,
      );

  @override
  String toString() => 'SoliplexConfig('
      'appName: $appName, '
      'defaultBackendUrl: $defaultBackendUrl, '
      'oauthRedirectScheme: $oauthRedirectScheme, '
      'features: $features, '
      'theme: $theme, '
      'routes: $routes)';
}
