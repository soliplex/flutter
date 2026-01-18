import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/extension/soliplex_registry.dart';
import 'package:soliplex_frontend/core/models/features.dart';
import 'package:soliplex_frontend/core/models/soliplex_config.dart';

/// Shell configuration set at app startup.
///
/// This is populated by [initializeShellConfig] before runApp() and provides
/// the static configuration for white-label customization. Unlike the runtime
/// configProvider which handles user-configurable settings, this provider
/// holds immutable app-level configuration.
SoliplexConfig _shellConfig = const SoliplexConfig();

/// Registry for custom panels, commands, and routes.
SoliplexRegistry _registry = const EmptyRegistry();

/// Initializes the shell configuration.
///
/// Call this in main() BEFORE runApp() to set up white-label configuration.
///
/// Example:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   initializeShellConfig(
///     config: SoliplexConfig(
///       appName: 'MyBrand',
///       features: const Features(enableHttpInspector: false),
///     ),
///   );
///   runApp(const SoliplexApp());
/// }
/// ```
void initializeShellConfig({
  SoliplexConfig config = const SoliplexConfig(),
  SoliplexRegistry registry = const EmptyRegistry(),
}) {
  _shellConfig = config;
  _registry = registry;
}

/// Provider for the shell configuration.
///
/// This provides the static [SoliplexConfig] that was set at startup.
/// The configuration is immutable after app launch.
///
/// Use this to access branding, feature flags, and theme configuration:
/// ```dart
/// final config = ref.watch(shellConfigProvider);
/// final appName = config.appName;
/// final showInspector = config.features.enableHttpInspector;
/// ```
final shellConfigProvider = Provider<SoliplexConfig>((ref) {
  return _shellConfig;
});

/// Provider for the extension registry.
///
/// Provides access to custom panels, commands, and routes registered
/// by white-label apps.
final registryProvider = Provider<SoliplexRegistry>((ref) {
  return _registry;
});

/// Provider for feature flags.
///
/// Convenience provider for accessing features directly.
final featuresProvider = Provider<Features>((ref) {
  return ref.watch(shellConfigProvider).features;
});
