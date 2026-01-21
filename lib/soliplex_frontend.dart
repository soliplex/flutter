/// Soliplex Frontend - A white-label Flutter chat application shell.
///
/// This library provides the core components for building a customizable
/// AI chat application based on the Soliplex architecture.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:soliplex_frontend/soliplex_frontend.dart';
///
/// Future<void> main() async {
///   await runSoliplexApp(
///     config: SoliplexConfig(
///       appName: 'MyBrand',
///       features: Features(enableHttpInspector: false),
///     ),
///   );
/// }
/// ```
///
/// ## Configuration
///
/// Use `SoliplexConfig` to customize:
/// - App name and branding
/// - Feature flags (`Features`)
/// - Theme colors (`ThemeConfig`)
/// - Route visibility (`RouteConfig`)
///
library soliplex_frontend;

// Configuration models
export 'package:soliplex_frontend/core/models/features.dart';
export 'package:soliplex_frontend/core/models/route_config.dart';
export 'package:soliplex_frontend/core/models/soliplex_config.dart';
export 'package:soliplex_frontend/core/models/theme_config.dart';

// Design tokens (for custom themes)
export 'package:soliplex_frontend/design/tokens/colors.dart'
    show SoliplexColors, darkSoliplexColors, lightSoliplexColors;

// Entry point
export 'package:soliplex_frontend/run_soliplex_app.dart';
