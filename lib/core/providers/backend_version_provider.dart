import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';

/// Provider for backend version information.
///
/// Fetches version info from the backend's `/api/v1/installation/versions`
/// endpoint. The result is cached for the session.
///
/// **Usage Example**:
/// ```dart
/// final versionAsync = ref.watch(backendVersionInfoProvider);
/// versionAsync.when(
///   data: (info) => Text(info.soliplexVersion),
///   loading: () => const Text('Loading...'),
///   error: (_, __) => const Text('Unavailable'),
/// );
/// ```
final backendVersionInfoProvider = FutureProvider<BackendVersionInfo>((ref) {
  final api = ref.watch(apiProvider);
  return api.getBackendVersionInfo();
});
