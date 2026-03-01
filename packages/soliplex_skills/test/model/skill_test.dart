import 'package:soliplex_skills/soliplex_skills.dart';
import 'package:test/test.dart';

void main() {
  group('SkillMetadata', () {
    test('constructs with required fields', () {
      const meta = SkillMetadata(name: 'test', description: 'A test skill');
      expect(meta.name, 'test');
      expect(meta.description, 'A test skill');
      expect(meta.category, isNull);
      expect(meta.bridgeVersion, isNull);
      expect(meta.isGenerated, isFalse);
      expect(meta.extra, isEmpty);
    });

    test('equality compares all fields', () {
      const a = SkillMetadata(
        name: 'x',
        description: 'd',
        category: 'cat',
      );
      const b = SkillMetadata(
        name: 'x',
        description: 'd',
        category: 'cat',
      );
      const c = SkillMetadata(
        name: 'x',
        description: 'd',
        category: 'other',
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('toString includes name and category', () {
      const meta = SkillMetadata(
        name: 'foo',
        description: 'bar',
        category: 'charts',
      );
      expect(meta.toString(), contains('foo'));
      expect(meta.toString(), contains('charts'));
    });
  });

  group('MarkdownSkill', () {
    test('constructs and exposes content', () {
      const skill = MarkdownSkill(
        metadata: SkillMetadata(name: 'md', description: 'desc'),
        sourcePath: '/skills/md.md',
        content: '# Hello',
      );
      expect(skill.metadata.name, 'md');
      expect(skill.sourcePath, '/skills/md.md');
      expect(skill.content, '# Hello');
    });

    test('equality includes content', () {
      const a = MarkdownSkill(
        metadata: SkillMetadata(name: 'md', description: 'd'),
        sourcePath: '/a',
        content: 'body',
      );
      const b = MarkdownSkill(
        metadata: SkillMetadata(name: 'md', description: 'd'),
        sourcePath: '/a',
        content: 'body',
      );
      const c = MarkdownSkill(
        metadata: SkillMetadata(name: 'md', description: 'd'),
        sourcePath: '/a',
        content: 'different',
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('is a Skill', () {
      const skill = MarkdownSkill(
        metadata: SkillMetadata(name: 'md', description: 'd'),
        sourcePath: '/a',
        content: '',
      );
      expect(skill, isA<Skill>());
    });
  });

  group('PythonSkill', () {
    test('constructs and exposes code', () {
      const skill = PythonSkill(
        metadata: SkillMetadata(name: 'py', description: 'desc'),
        sourcePath: '/skills/py.py',
        code: 'print("hi")',
      );
      expect(skill.metadata.name, 'py');
      expect(skill.code, 'print("hi")');
    });

    test('equality includes code', () {
      const a = PythonSkill(
        metadata: SkillMetadata(name: 'py', description: 'd'),
        sourcePath: '/a',
        code: 'x = 1',
      );
      const b = PythonSkill(
        metadata: SkillMetadata(name: 'py', description: 'd'),
        sourcePath: '/a',
        code: 'x = 1',
      );
      const c = PythonSkill(
        metadata: SkillMetadata(name: 'py', description: 'd'),
        sourcePath: '/a',
        code: 'x = 2',
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('is a Skill', () {
      const skill = PythonSkill(
        metadata: SkillMetadata(name: 'py', description: 'd'),
        sourcePath: '/a',
        code: '',
      );
      expect(skill, isA<Skill>());
    });
  });

  group('sealed Skill exhaustiveness', () {
    test('switch covers all cases', () {
      const Skill skill = MarkdownSkill(
        metadata: SkillMetadata(name: 'md', description: 'd'),
        sourcePath: '/a',
        content: 'body',
      );

      final result = switch (skill) {
        MarkdownSkill() => 'markdown',
        PythonSkill() => 'python',
      };
      expect(result, 'markdown');
    });
  });
}
