import 'package:soliplex_frontend/soliplex_frontend.dart';

/// Entry point for the default Soliplex application.
///
/// For white-label apps, create your own main.dart with custom configuration:
/// ```dart
/// import 'package:soliplex_frontend/soliplex_frontend.dart';
///
/// Future<void> main() async {
///   await runSoliplexApp(
///     config: SoliplexConfig(
///       logo: LogoConfig(assetPath: 'assets/my_logo.png'),
///       appName: 'MyBrand',
///       defaultBackendUrl: 'https://api.mybrand.com',
///     ),
///   );
/// }
/// ```
Future<void> main() async {
  await runSoliplexApp(
    config: const SoliplexConfig(
      logo: LogoConfig.soliplex,
      oauthRedirectScheme: 'ai.soliplex.client',
    ),
  );
}
