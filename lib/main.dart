import 'package:soliplex_frontend/soliplex_frontend.dart';

/// Entry point for the default Soliplex application.
///
/// For white-label apps, create your own main.dart with custom configuration:
/// ```dart
/// import 'package:soliplex_frontend/soliplex_frontend.dart';
///
/// void main() {
///   runSoliplexApp(
///     config: SoliplexConfig(
///       appName: 'MyBrand',
///       defaultBackendUrl: 'https://api.mybrand.com',
///     ),
///   );
/// }
/// ```
void main() {
  runSoliplexApp();
}
