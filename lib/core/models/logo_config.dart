import 'package:meta/meta.dart';

/// Configuration for the app logo displayed in UI.
@immutable
class LogoConfig {
  /// Creates a logo configuration.
  ///
  /// [assetPath] is the path to the logo asset (e.g., `'assets/logo.png'`).
  /// Must not be empty.
  ///
  /// [package] specifies which package contains the asset:
  /// - `null` (default): Load from the current app's assets
  /// - Package name string: Load from the specified package's assets
  const LogoConfig({
    required this.assetPath,
    this.package,
  }) : assert(assetPath.length > 0, 'assetPath cannot be empty');

  /// Default Soliplex logo from the library's bundled assets.
  ///
  /// White-label apps should provide their own [LogoConfig] pointing to
  /// custom branding assets.
  static const soliplex = LogoConfig(
    assetPath: 'assets/branding/logo_1024.png',
  );

  /// Path to the logo asset, relative to the assets directory.
  final String assetPath;

  /// Package containing the logo asset.
  ///
  /// - `null` (default): Load from the current app's assets
  /// - Package name string: Load from the specified package's assets
  final String? package;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogoConfig &&
          runtimeType == other.runtimeType &&
          assetPath == other.assetPath &&
          package == other.package;

  @override
  int get hashCode => Object.hash(assetPath, package);

  @override
  String toString() => 'LogoConfig(assetPath: $assetPath, package: $package)';
}
