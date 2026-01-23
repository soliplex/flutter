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
///       appName: 'MyBrand',
///       defaultBackendUrl: 'https://api.mybrand.com',
///     ),
///   );
/// }
/// ```
Future<void> main() async {
  await runSoliplexApp(
    config: const SoliplexConfig(oauthRedirectScheme: 'ai.soliplex.client'),
  );
}
