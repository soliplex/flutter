import 'package:soliplex_client/soliplex_client.dart';

/// Key for per-thread document selection.
///
/// Selections are stored indexed by both room ID and thread ID to ensure
/// complete isolation between threads, even across different rooms.
typedef ThreadKey = ({String roomId, String threadId});

/// Provides access to per-thread document selections.
abstract class DocumentSelection {
  /// Gets the selection for a specific thread.
  ///
  /// Returns an empty set if no documents are selected for the thread.
  Set<RagDocument> getForThread(String roomId, String threadId);

  /// Updates the selection for a specific thread.
  ///
  /// Replaces any existing selection for the thread.
  void setForThread(
    String roomId,
    String threadId,
    Set<RagDocument> documents,
  );
}
