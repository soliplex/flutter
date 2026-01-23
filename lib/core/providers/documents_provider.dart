import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';

/// Provider for documents in a specific room.
///
/// Fetches documents from the backend API using [SoliplexApi.getDocuments].
/// Each room's documents are cached separately by Riverpod's family provider.
///
/// **Usage**:
/// ```dart
/// // Read documents for a room
/// final docsAsync = ref.watch(documentsProvider('room-id'));
///
/// // Refresh documents for a room
/// ref.refresh(documentsProvider('room-id'));
/// ```
///
/// **Error Handling**:
/// Throws [SoliplexException] subtypes which should be handled in the UI:
/// - [NetworkException]: Connection failures, timeouts
/// - [NotFoundException]: Room not found (404)
/// - [AuthException]: 401/403 authentication errors
/// - [ApiException]: Other server errors
final documentsProvider = FutureProvider.family<List<RagDocument>, String>((
  ref,
  roomId,
) async {
  final api = ref.watch(apiProvider);
  return api.getDocuments(roomId);
});
