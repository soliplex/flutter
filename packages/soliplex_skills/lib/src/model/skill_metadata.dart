import 'package:meta/meta.dart';

/// Metadata extracted from a skill's YAML frontmatter.
@immutable
class SkillMetadata {
  const SkillMetadata({
    required this.name,
    required this.description,
    this.category,
    this.bridgeVersion,
    this.isGenerated = false,
    this.extra = const {},
  });

  /// Skill identifier (e.g. `"monty-df"`).
  final String name;

  /// Human-readable description of what the skill does.
  final String description;

  /// Optional grouping category (e.g. `"df"`, `"chart"`).
  final String? category;

  /// Bridge API version this skill targets.
  final String? bridgeVersion;

  /// Whether this skill was auto-generated.
  final bool isGenerated;

  /// Additional key-value pairs from frontmatter metadata.
  final Map<String, dynamic> extra;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillMetadata &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          description == other.description &&
          category == other.category &&
          bridgeVersion == other.bridgeVersion &&
          isGenerated == other.isGenerated;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        name,
        description,
        category,
        bridgeVersion,
        isGenerated,
      );

  @override
  String toString() => 'SkillMetadata(name: $name, category: $category)';
}
