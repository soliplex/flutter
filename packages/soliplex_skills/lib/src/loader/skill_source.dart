import 'package:soliplex_skills/src/model/skill.dart';

/// Interface for loading skills from a source (filesystem, server, etc.).
abstract class SkillSource {
  /// Loads all available skills from this source.
  Future<List<Skill>> loadAll();
}

/// Error encountered while loading a skill.
class SkillLoadException implements Exception {
  const SkillLoadException(this.path, this.message, [this.cause]);

  /// Path or identifier of the skill that failed to load.
  final String path;

  /// Human-readable description of the failure.
  final String message;

  /// Underlying exception, if any.
  final Object? cause;

  @override
  String toString() => 'SkillLoadException($path): $message';
}
