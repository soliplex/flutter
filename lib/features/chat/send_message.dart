import 'package:soliplex_client/soliplex_client.dart';

import 'package:soliplex_frontend/core/document_selection.dart';
import 'package:soliplex_frontend/core/models/agui_features/filter_documents.dart';
import 'package:soliplex_frontend/core/models/agui_features/filter_documents_ext.dart';

/// Starts an AG-UI run for a thread.
typedef StartRun = Future<void> Function({
  required String roomId,
  required String threadId,
  required String userMessage,
  String? existingRunId,
  Map<String, dynamic>? initialState,
});

/// Result of sending a message.
typedef SendMessageResult = ({
  String threadId,
  String roomId,
  bool isNewThread,
});

/// Orchestrates thread creation, document transfer, and run initiation.
class SendMessage {
  SendMessage({
    required SoliplexApi api,
    required StartRun startRun,
    required DocumentSelection documentSelection,
  })  : _api = api,
        _startRun = startRun,
        _documentSelection = documentSelection;

  final SoliplexApi _api;
  final StartRun _startRun;
  final DocumentSelection _documentSelection;

  /// Sends a message, creating a new thread if needed.
  ///
  /// When [currentThread] is null or [isNewThreadIntent] is true,
  /// creates a new thread and transfers pending documents to it.
  /// Then starts a run with the given [text].
  Future<SendMessageResult> call({
    required String roomId,
    required String text,
    required Set<RagDocument> pendingDocuments,
    ThreadInfo? currentThread,
    bool isNewThreadIntent = false,
  }) async {
    final isNewThread = currentThread == null || isNewThreadIntent;

    final ThreadInfo effectiveThread;
    if (isNewThread) {
      effectiveThread = await _api.createThread(roomId);

      if (pendingDocuments.isNotEmpty) {
        _documentSelection.setForThread(
          roomId,
          effectiveThread.id,
          pendingDocuments,
        );
      }
    } else {
      effectiveThread = currentThread;
    }

    // For new threads, use the pending docs we just transferred.
    // For existing threads, read from the store.
    final selectedDocuments = isNewThread
        ? pendingDocuments
        : _documentSelection.getForThread(roomId, effectiveThread.id);

    Map<String, dynamic>? initialState;
    if (selectedDocuments.isNotEmpty) {
      initialState = FilterDocuments(
        documentIds: selectedDocuments.map((d) => d.id).toList(),
      ).toStateEntry();
    }

    await _startRun(
      roomId: roomId,
      threadId: effectiveThread.id,
      userMessage: text,
      existingRunId: effectiveThread.initialRunId,
      initialState: initialState,
    );

    return (
      threadId: effectiveThread.id,
      roomId: roomId,
      isNewThread: isNewThread,
    );
  }
}
