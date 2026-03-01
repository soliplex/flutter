import 'package:soliplex_skills/src/loader/skill_source.dart';
import 'package:soliplex_skills/src/model/skill.dart';

/// Loads skills from a remote server.
///
// TODO(skills): implement server-backed skill loading via API.
class ServerSkillSource implements SkillSource {
  const ServerSkillSource({required this.baseUrl});

  /// Base URL of the skill server API.
  final String baseUrl;

  @override
  Future<List<Skill>> loadAll() async => [];
}
