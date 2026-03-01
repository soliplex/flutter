import 'package:soliplex_skills/soliplex_skills.dart';
import 'package:test/test.dart';

void main() {
  group('executeMarkdownSkill', () {
    test('returns MessageInjection with system role by default', () {
      const skill = MarkdownSkill(
        metadata: SkillMetadata(name: 'sys', description: 'system prompt'),
        sourcePath: '/skills/sys.md',
        content: 'You are a helpful assistant.',
      );

      final result = executeMarkdownSkill(skill);

      expect(result, isA<MessageInjection>());
      expect(result.role, MessageRole.system);
      expect(result.content, 'You are a helpful assistant.');
    });

    test('uses user role when specified in extra', () {
      const skill = MarkdownSkill(
        metadata: SkillMetadata(
          name: 'usr',
          description: 'user prompt',
          extra: {'role': 'user'},
        ),
        sourcePath: '/skills/usr.md',
        content: 'Please analyse this data.',
      );

      final result = executeMarkdownSkill(skill);

      expect(result.role, MessageRole.user);
      expect(result.content, 'Please analyse this data.');
    });

    test('defaults to system for unknown role value', () {
      const skill = MarkdownSkill(
        metadata: SkillMetadata(
          name: 'x',
          description: 'd',
          extra: {'role': 'unknown'},
        ),
        sourcePath: '/x.md',
        content: 'body',
      );

      final result = executeMarkdownSkill(skill);
      expect(result.role, MessageRole.system);
    });
  });
}
