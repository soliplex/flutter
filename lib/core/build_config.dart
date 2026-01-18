/// App display name for titles and branding.
///
/// @Deprecated Use `SoliplexConfig.appName` via `shellConfigProvider` instead.
/// This constant is kept for backwards compatibility with build systems that
/// use `--dart-define=APP_NAME=MyBrand`.
///
/// For new code, configure the app name via `initializeShellConfig`:
/// ```dart
/// initializeShellConfig(
///   config: SoliplexConfig(appName: 'MyBrand'),
/// );
/// ```
@Deprecated('Use SoliplexConfig.appName via shellConfigProvider instead')
const appName = String.fromEnvironment('APP_NAME', defaultValue: 'Soliplex');
