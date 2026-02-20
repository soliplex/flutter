import 'package:meta/meta.dart';
import 'package:soliplex_frontend/core/models/consent_notice.dart';
import 'package:soliplex_frontend/core/models/features.dart';
import 'package:soliplex_frontend/core/models/logo_config.dart';
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
///   logo: LogoConfig(assetPath: 'assets/my_logo.png'),
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
  /// Creates a Soliplex configuration.
  ///
  /// [logo] is required to ensure white-label apps explicitly configure
  /// branding. Use [LogoConfig.soliplex] for the default Soliplex logo.
  const SoliplexConfig({
    required this.logo,
    this.appName = 'Soliplex',
    this.defaultBackendUrl = 'http://localhost:8000',
    this.oauthRedirectScheme,
    this.consentNotice,
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
  /// Defaults to `http://localhost:8000`. On native and web localhost,
  /// this value is used directly. On web production, the client's origin
  /// is used instead (ignoring this value).
  ///
  /// Overridden when the user connects to a different backend from the
  /// home screen (persisted to SharedPreferences for subsequent launches).
  final String defaultBackendUrl;

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

  /// Logo configuration for branding.
  ///
  /// Use [LogoConfig.soliplex] for the default Soliplex logo.
  /// White-label apps should provide their own [LogoConfig] with custom assets.
  final LogoConfig logo;

  /// Feature flags controlling which functionality is available.
  final Features features;

  /// Theme configuration for light and dark mode colors.
  final ThemeConfig theme;

  /// Consent-to-monitoring notice shown before login.
  ///
  /// When non-null, users must acknowledge this notice before seeing
  /// login options. Used by regulated deployments.
  final ConsentNotice? consentNotice;

  /// Route configuration for navigation behavior.
  final RouteConfig routes;

  /// Creates a copy with the specified fields replaced.
  SoliplexConfig copyWith({
    String? appName,
    String? defaultBackendUrl,
    String? oauthRedirectScheme,
    LogoConfig? logo,
    ConsentNotice? consentNotice,
    Features? features,
    ThemeConfig? theme,
    RouteConfig? routes,
  }) {
    return SoliplexConfig(
      appName: appName ?? this.appName,
      defaultBackendUrl: defaultBackendUrl ?? this.defaultBackendUrl,
      oauthRedirectScheme: oauthRedirectScheme ?? this.oauthRedirectScheme,
      logo: logo ?? this.logo,
      consentNotice: consentNotice ?? this.consentNotice,
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
          logo == other.logo &&
          consentNotice == other.consentNotice &&
          features == other.features &&
          theme == other.theme &&
          routes == other.routes;

  @override
  int get hashCode => Object.hash(
        appName,
        defaultBackendUrl,
        oauthRedirectScheme,
        logo,
        consentNotice,
        features,
        theme,
        routes,
      );

  @override
  String toString() => 'SoliplexConfig('
      'appName: $appName, '
      'defaultBackendUrl: $defaultBackendUrl, '
      'oauthRedirectScheme: $oauthRedirectScheme, '
      'logo: $logo, '
      'consentNotice: $consentNotice, '
      'features: $features, '
      'theme: $theme, '
      'routes: $routes)';
}
