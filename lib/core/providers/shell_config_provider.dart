import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/models/features.dart';
import 'package:soliplex_frontend/core/models/soliplex_config.dart';

/// Provider for the shell configuration.
///
/// This provider MUST be overridden in [ProviderScope] at app startup.
/// It throws [UnimplementedError] if accessed without being overridden.
///
/// Use this to access branding, feature flags, and theme configuration:
/// ```dart
/// final config = ref.watch(shellConfigProvider);
/// final appName = config.appName;
/// final showInspector = config.features.enableHttpInspector;
/// ```
///
/// Override in your app's entry point:
/// ```dart
/// ProviderScope(
///   overrides: [
///     shellConfigProvider.overrideWithValue(myConfig),
///   ],
///   child: const SoliplexApp(),
/// )
/// ```
final shellConfigProvider = Provider<SoliplexConfig>((ref) {
  throw UnimplementedError(
    'shellConfigProvider must be overridden in ProviderScope. '
    'Use runSoliplexApp() or manually override in ProviderScope.',
  );
});

/// Provider for feature flags.
///
/// Convenience provider for accessing features directly.
final featuresProvider = Provider<Features>((ref) {
  return ref.watch(shellConfigProvider).features;
});
