import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';

/// Provider for fetching chunk visualization by room and chunk ID.
///
/// **Usage**:
/// ```dart
/// final chunkAsync = ref.watch(
///   chunkVisualizationProvider((roomId: 'room-1', chunkId: 'chunk-1')),
/// );
/// ```
///
/// **Error Handling**:
/// Throws [SoliplexException] subtypes which should be handled in the UI:
/// - [NetworkException]: Connection failures, timeouts
/// - [NotFoundException]: Chunk not found (404)
/// - [AuthException]: 401/403 authentication errors
/// - [ApiException]: Other server errors
final chunkVisualizationProvider = FutureProvider.autoDispose
    .family<ChunkVisualization, ({String roomId, String chunkId})>((
  ref,
  params,
) async {
  final api = ref.watch(apiProvider);
  return api.getChunkVisualization(params.roomId, params.chunkId);
});
