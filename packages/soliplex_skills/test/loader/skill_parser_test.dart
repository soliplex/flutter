import 'package:soliplex_skills/soliplex_skills.dart';
import 'package:test/test.dart';

void main() {
  group('SkillParser.extractFrontmatter', () {
    test('parses YAML between --- delimiters', () {
      const raw = '---\n'
          'name: test-skill\n'
          'description: A test\n'
          'metadata:\n'
          '  category: charts\n'
          '---\n'
          '# Body content here';

      final (map, body) = SkillParser.extractFrontmatter(raw);

      expect(map['name'], 'test-skill');
      expect(map['description'], 'A test');
      expect((map['metadata'] as Map)['category'], 'charts');
      expect(body, '# Body content here');
    });

    test('returns empty map when no frontmatter', () {
      const raw = '# Just markdown\nNo frontmatter here.';
      final (map, body) = SkillParser.extractFrontmatter(raw);

      expect(map, isEmpty);
      expect(body, raw);
    });

    test('returns empty map when only opening ---', () {
      const raw = '---\nname: broken';
      final (map, body) = SkillParser.extractFrontmatter(raw);

      expect(map, isEmpty);
      expect(body, raw);
    });

    test('handles leading whitespace', () {
      const raw = '  ---\n'
          'name: indented\n'
          '---\n'
          'body';

      final (map, body) = SkillParser.extractFrontmatter(raw);
      expect(map['name'], 'indented');
      expect(body, 'body');
    });
  });

  group('SkillParser.parseMarkdown', () {
    test('parses frontmatter into SkillMetadata', () {
      const raw = '---\n'
          'name: monty-df\n'
          'description: DataFrame operations\n'
          'metadata:\n'
          '  bridge_version: "1"\n'
          '  category: df\n'
          '  generated: "true"\n'
          '---\n'
          'You are a DataFrame assistant.';

      final skill = SkillParser.parseMarkdown('/skills/monty-df.md', raw);

      expect(skill, isA<MarkdownSkill>());
      expect(skill.metadata.name, 'monty-df');
      expect(skill.metadata.description, 'DataFrame operations');
      expect(skill.metadata.category, 'df');
      expect(skill.metadata.bridgeVersion, '1');
      expect(skill.metadata.isGenerated, isTrue);
      expect(skill.content, 'You are a DataFrame assistant.');
      expect(skill.sourcePath, '/skills/monty-df.md');
    });

    test('derives name from filename when not in frontmatter', () {
      const raw = '---\n'
          'description: No name field\n'
          '---\n'
          'body';

      final skill = SkillParser.parseMarkdown('/skills/my-skill.md', raw);
      expect(skill.metadata.name, 'my-skill');
    });

    test('handles file with no frontmatter', () {
      const raw = '# Just a markdown file';
      final skill = SkillParser.parseMarkdown('/skills/plain.md', raw);

      expect(skill.metadata.name, 'plain');
      expect(skill.metadata.description, '');
      expect(skill.content, raw);
    });

    test('preserves extra metadata keys', () {
      const raw = '---\n'
          'name: extra\n'
          'description: has extras\n'
          'metadata:\n'
          '  category: test\n'
          '  custom_key: custom_value\n'
          '---\n'
          'body';

      final skill = SkillParser.parseMarkdown('/skills/extra.md', raw);
      expect(skill.metadata.extra['custom_key'], 'custom_value');
      expect(skill.metadata.extra.containsKey('category'), isFalse);
    });
  });

  group('SkillParser.parsePython', () {
    test('extracts metadata from docstring frontmatter', () {
      const raw = '"""\n'
          '---\n'
          'name: hello\n'
          'description: Says hello\n'
          'metadata:\n'
          '  category: demo\n'
          '---\n'
          '"""\n'
          'print("hello")';

      final skill = SkillParser.parsePython('/skills/hello.py', raw);

      expect(skill, isA<PythonSkill>());
      expect(skill.metadata.name, 'hello');
      expect(skill.metadata.description, 'Says hello');
      expect(skill.metadata.category, 'demo');
      expect(skill.code, raw);
    });

    test('uses sidecar YAML when provided', () {
      const code = 'print("hello")';
      const sidecar = 'name: hello\n'
          'description: Says hello\n'
          'metadata:\n'
          '  category: demo\n';

      final skill = SkillParser.parsePython(
        '/skills/hello.py',
        code,
        sidecarYaml: sidecar,
      );

      expect(skill.metadata.name, 'hello');
      expect(skill.metadata.description, 'Says hello');
      expect(skill.code, code);
    });

    test('derives name from filename when no metadata', () {
      const code = 'x = 1';
      final skill = SkillParser.parsePython('/skills/simple.py', code);

      expect(skill.metadata.name, 'simple');
      expect(skill.metadata.description, '');
    });

    test('handles single-quoted docstrings', () {
      const raw =
          "'''\n---\nname: single\ndescription: single quotes\n---\n'''\nx = 1";

      final skill = SkillParser.parsePython('/skills/single.py', raw);
      expect(skill.metadata.name, 'single');
    });
  });
}
