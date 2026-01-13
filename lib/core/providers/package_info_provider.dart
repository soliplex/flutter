import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Provider for app package info (version, build number, app name).
///
/// MUST be overridden in ProviderScope at app startup.
final packageInfoProvider = Provider<PackageInfo>((ref) {
  throw UnimplementedError(
    'packageInfoProvider must be overridden in ProviderScope',
  );
});
