import 'dart:developer' as developer;

import 'package:soliplex_client/src/domain/source_reference.dart';
import 'package:soliplex_client/src/schema/agui_features/ask_history.dart'
    as ask_history;
import 'package:soliplex_client/src/schema/agui_features/haiku_rag_chat.dart';

Never _throwFromJsonDiagnostic(
  String className,
  Map<String, dynamic> json,
  Object error,
  StackTrace stackTrace,
) {
  final nullKeys =
      json.entries.where((e) => e.value == null).map((e) => e.key).toList();
  final presentKeys = json.keys.toList();

  final message = '$className.fromJson failed ($error). '
      'Null keys: $nullKeys. Present keys: $presentKeys.';

  developer.log(
    message,
    name: 'soliplex_client.citation_extractor',
    level: 900,
    error: error,
    stackTrace: stackTrace,
  );

  Error.throwWithStackTrace(FormatException(message), stackTrace);
}

/// Extracts new [SourceReference]s by comparing AG-UI state snapshots.
///
/// This is the **schema firewall**: the only file that imports schema types.
/// When generated schema classes change, only this file needs updating.
///
/// Uses length-based detection: compares `len(previous)` vs `len(current)`
/// to find new entries at indices `[previousLength, currentLength)`.
class CitationExtractor {
  /// Extracts source references from entries added since [previousState].
  ///
  /// Returns an empty list if:
  /// - No recognized state format is found
  /// - Current has same or fewer entries than previous (FIFO rotation)
  /// - New entries have no citations
  List<SourceReference> extractNew(
    Map<String, dynamic> previousState,
    Map<String, dynamic> currentState,
  ) {
    // Try haiku.rag.chat first (primary format)
    final haikuRefs = _extractFromHaikuRagChat(previousState, currentState);
    if (haikuRefs.isNotEmpty) return haikuRefs;

    // Fall back to ask_history
    return _extractFromAskHistory(previousState, currentState);
  }

  List<SourceReference> _extractFromHaikuRagChat(
    Map<String, dynamic> previousState,
    Map<String, dynamic> currentState,
  ) {
    final previousData =
        previousState['haiku.rag.chat'] as Map<String, dynamic>?;
    final currentData = currentState['haiku.rag.chat'] as Map<String, dynamic>?;

    if (currentData == null) return [];

    final previousLength = _getQaHistoryLength(previousData);
    final currentLength = _getQaHistoryLength(currentData);

    if (currentLength <= previousLength) return [];

    try {
      // Ensure citation_registry has a default — required by fromJson but
      // may be absent in STATE_DELTA events that only include qa_history.
      final normalizedData = {
        'citation_registry': const <String, int>{},
        ...currentData,
      };
      final haikuRagChat = HaikuRagChat.fromJson(normalizedData);
      final qaHistory = haikuRagChat.qaHistory ?? [];

      return qaHistory
          .sublist(previousLength)
          .expand(_extractFromQaResponse)
          .toList();
    } catch (e, stackTrace) {
      _throwFromJsonDiagnostic('HaikuRagChat', currentData, e, stackTrace);
    }
  }

  int _getQaHistoryLength(Map<String, dynamic>? data) {
    if (data == null) return 0;
    final qaHistory = data['qa_history'] as List<dynamic>?;
    return qaHistory?.length ?? 0;
  }

  List<SourceReference> _extractFromQaResponse(QaResponse entry) {
    final citations = entry.citations ?? [];
    return citations.map(_citationToSourceReference).toList();
  }

  SourceReference _citationToSourceReference(Citation c) {
    return SourceReference(
      documentId: c.documentId,
      documentUri: c.documentUri,
      content: c.content,
      chunkId: c.chunkId,
      documentTitle: c.documentTitle,
      headings: c.headings ?? [],
      pageNumbers: c.pageNumbers ?? [],
      index: c.index,
    );
  }

  List<SourceReference> _extractFromAskHistory(
    Map<String, dynamic> previousState,
    Map<String, dynamic> currentState,
  ) {
    final previousData = previousState['ask_history'] as Map<String, dynamic>?;
    final currentData = currentState['ask_history'] as Map<String, dynamic>?;

    if (currentData == null) return [];

    final previousLength = _getQuestionsLength(previousData);
    final currentLength = _getQuestionsLength(currentData);

    if (currentLength <= previousLength) return [];

    try {
      final history = ask_history.AskHistory.fromJson(currentData);
      final questions = history.questions ?? [];

      return questions
          .sublist(previousLength)
          .expand(_extractFromQuestionResponse)
          .toList();
    } catch (e, stackTrace) {
      _throwFromJsonDiagnostic('AskHistory', currentData, e, stackTrace);
    }
  }

  int _getQuestionsLength(Map<String, dynamic>? data) {
    if (data == null) return 0;
    final questions = data['questions'] as List<dynamic>?;
    return questions?.length ?? 0;
  }

  List<SourceReference> _extractFromQuestionResponse(
    ask_history.QuestionResponseCitations entry,
  ) {
    final citations = entry.citations ?? [];
    return citations.map(_askCitationToSourceReference).toList();
  }

  SourceReference _askCitationToSourceReference(ask_history.Citation c) {
    return SourceReference(
      documentId: c.documentId,
      documentUri: c.documentUri,
      content: c.content,
      chunkId: c.chunkId,
      documentTitle: c.documentTitle,
      headings: c.headings ?? [],
      pageNumbers: c.pageNumbers ?? [],
      index: c.index,
    );
  }
}
