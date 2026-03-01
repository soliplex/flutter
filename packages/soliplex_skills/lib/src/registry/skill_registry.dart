import 'package:meta/meta.dart';
import 'package:soliplex_skills/src/loader/skill_source.dart';
import 'package:soliplex_skills/src/model/skill.dart';

/// Immutable registry of loaded skills.
///
/// Every mutation returns a new [SkillRegistry] instance.
@immutable
class SkillRegistry {
  /// Creates an empty registry.
  const SkillRegistry() : _skills = const {};

  const SkillRegistry._(this._skills);

  final Map<String, Skill> _skills;

  /// Registers a single [skill] and returns a new registry containing it.
  SkillRegistry register(Skill skill) {
    return SkillRegistry._({..._skills, skill.metadata.name: skill});
  }

  /// Registers multiple [skills] and returns a new registry containing them.
  SkillRegistry registerAll(Iterable<Skill> skills) {
    final updated = {..._skills};
    for (final skill in skills) {
      updated[skill.metadata.name] = skill;
    }
    return SkillRegistry._(updated);
  }

  /// Returns the skill registered under [name].
  ///
  /// Throws [StateError] if not found.
  Skill lookup(String name) {
    final skill = _skills[name];
    if (skill == null) {
      throw StateError('No skill registered with name "$name"');
    }
    return skill;
  }

  /// Returns the skill registered under [name], or `null` if not found.
  Skill? tryLookup(String name) => _skills[name];

  /// Whether a skill with [name] is registered.
  bool contains(String name) => _skills.containsKey(name);

  /// All registered skills.
  List<Skill> get all => List.unmodifiable(_skills.values);

  /// All registered [MarkdownSkill]s.
  List<MarkdownSkill> get markdownSkills =>
      _skills.values.whereType<MarkdownSkill>().toList(growable: false);

  /// All registered [PythonSkill]s.
  List<PythonSkill> get pythonSkills =>
      _skills.values.whereType<PythonSkill>().toList(growable: false);

  /// Skills matching a given [category].
  List<Skill> byCategory(String category) => _skills.values
      .where((s) => s.metadata.category == category)
      .toList(growable: false);

  /// Number of registered skills.
  int get length => _skills.length;

  /// Whether the registry is empty.
  bool get isEmpty => _skills.isEmpty;
}

/// Loads skills from multiple [sources] into a [SkillRegistry].
///
/// Collects load errors without throwing so partial results are returned.
Future<(SkillRegistry, List<SkillLoadException>)> loadSkillRegistry(
  List<SkillSource> sources,
) async {
  var registry = const SkillRegistry();
  final errors = <SkillLoadException>[];

  for (final source in sources) {
    try {
      final skills = await source.loadAll();
      registry = registry.registerAll(skills);
    } on SkillLoadException catch (e) {
      errors.add(e);
    } on Exception catch (e) {
      errors.add(SkillLoadException('unknown', e.toString(), e));
    }
  }

  return (registry, errors);
}
