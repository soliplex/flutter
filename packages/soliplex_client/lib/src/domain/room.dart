import 'package:meta/meta.dart';

/// Represents a room from the backend.
@immutable
class Room {
  /// Creates a room.
  const Room({
    required this.id,
    required this.name,
    this.description = '',
    this.metadata = const {},
    this.quizzes = const {},
    this.suggestions = const [],
  });

  /// Unique identifier for the room.
  final String id;

  /// Display name of the room.
  final String name;

  /// Description of the room (empty string if not provided).
  final String description;

  /// Metadata for the room (empty map if not provided).
  final Map<String, dynamic> metadata;

  /// Quizzes available in this room, keyed by quiz ID with title as value.
  final Map<String, String> quizzes;

  /// Suggested prompts to show when starting a new thread.
  final List<String> suggestions;

  /// Quiz IDs available in this room.
  List<String> get quizIds => quizzes.keys.toList();

  /// Whether the room has a description.
  bool get hasDescription => description.isNotEmpty;

  /// Whether the room has any quizzes.
  bool get hasQuizzes => quizzes.isNotEmpty;

  /// Whether the room has any suggestions.
  bool get hasSuggestions => suggestions.isNotEmpty;

  /// Creates a copy of this room with the given fields replaced.
  Room copyWith({
    String? id,
    String? name,
    String? description,
    Map<String, dynamic>? metadata,
    Map<String, String>? quizzes,
    List<String>? suggestions,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      quizzes: quizzes ?? this.quizzes,
      suggestions: suggestions ?? this.suggestions,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Room && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Room(id: $id, name: $name)';
}
