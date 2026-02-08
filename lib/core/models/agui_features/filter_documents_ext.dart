import 'package:soliplex_frontend/core/models/agui_features/filter_documents.dart';

/// Extension to add AG-UI state serialization to [FilterDocuments].
///
/// This keeps the state key co-located with the class without modifying
/// the generated code in filter_documents.dart.
extension FilterDocumentsState on FilterDocuments {
  /// The key used in AG-UI state for document filtering.
  static const String stateKey = 'filter_documents';

  /// Returns a map suitable for merging into AG-UI initial state.
  Map<String, dynamic> toStateEntry() => {stateKey: toJson()};
}
