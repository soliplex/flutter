import 'package:meta/meta.dart';
import 'package:soliplex_skills/src/model/skill_metadata.dart';

/// A loadable skill — either a Markdown prompt or Python code.
@immutable
sealed class Skill {
  const Skill({required this.metadata, required this.sourcePath});

  /// Parsed frontmatter metadata.
  final SkillMetadata metadata;

  /// Filesystem path or URI where the skill was loaded from.
  final String sourcePath;
}

/// A Markdown skill whose body is injected as a chat message.
@immutable
final class MarkdownSkill extends Skill {
  const MarkdownSkill({
    required super.metadata,
    required super.sourcePath,
    required this.content,
  });

  /// Markdown body after the frontmatter.
  final String content;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownSkill &&
          runtimeType == other.runtimeType &&
          metadata == other.metadata &&
          sourcePath == other.sourcePath &&
          content == other.content;

  @override
  int get hashCode => Object.hash(runtimeType, metadata, sourcePath, content);

  @override
  String toString() => 'MarkdownSkill(name: ${metadata.name})';
}

/// A Python skill executed in the Monty sandbox.
@immutable
final class PythonSkill extends Skill {
  const PythonSkill({
    required super.metadata,
    required super.sourcePath,
    required this.code,
  });

  /// Python source code.
  final String code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PythonSkill &&
          runtimeType == other.runtimeType &&
          metadata == other.metadata &&
          sourcePath == other.sourcePath &&
          code == other.code;

  @override
  int get hashCode => Object.hash(runtimeType, metadata, sourcePath, code);

  @override
  String toString() => 'PythonSkill(name: ${metadata.name})';
}
