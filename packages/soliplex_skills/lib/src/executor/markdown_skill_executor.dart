import 'package:soliplex_skills/src/executor/skill_executor.dart';
import 'package:soliplex_skills/src/model/skill.dart';

/// Executes a [MarkdownSkill] by returning its content as a [MessageInjection].
MessageInjection executeMarkdownSkill(MarkdownSkill skill) {
  final roleStr = skill.metadata.extra['role'] as String?;
  final role = roleStr == 'user' ? MessageRole.user : MessageRole.system;

  return MessageInjection(role: role, content: skill.content);
}
