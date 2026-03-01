import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:soliplex_skills/soliplex_skills.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('skills_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('FilesystemSkillSource', () {
    test('loads flat .md files', () async {
      const content = '---\n'
          'name: greeting\n'
          'description: A greeting prompt\n'
          '---\n'
          'Hello, how can I help?';
      File(p.join(tempDir.path, 'greeting.md')).writeAsStringSync(content);

      final source = FilesystemSkillSource(tempDir);
      final skills = await source.loadAll();

      expect(skills, hasLength(1));
      expect(skills.first, isA<MarkdownSkill>());
      expect(skills.first.metadata.name, 'greeting');
      expect(
        (skills.first as MarkdownSkill).content,
        'Hello, how can I help?',
      );
    });

    test('loads flat .py files', () async {
      File(p.join(tempDir.path, 'hello.py')).writeAsStringSync(
        'print("hello")',
      );

      final source = FilesystemSkillSource(tempDir);
      final skills = await source.loadAll();

      expect(skills, hasLength(1));
      expect(skills.first, isA<PythonSkill>());
      expect(skills.first.metadata.name, 'hello');
    });

    test('loads directory-style SKILL.md', () async {
      final skillDir = Directory(p.join(tempDir.path, 'my-skill'))
        ..createSync();
      const content = '---\n'
          'name: my-skill\n'
          'description: Directory skill\n'
          '---\n'
          'Body text.';
      File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync(content);

      final source = FilesystemSkillSource(tempDir);
      final skills = await source.loadAll();

      expect(skills, hasLength(1));
      expect(skills.first, isA<MarkdownSkill>());
      expect(skills.first.metadata.name, 'my-skill');
    });

    test('loads .py with sidecar .yaml', () async {
      File(p.join(tempDir.path, 'calc.py')).writeAsStringSync(
        'result = 1 + 2',
      );
      const sidecar = 'name: calc\n'
          'description: Calculator\n'
          'metadata:\n'
          '  category: math\n';
      File(p.join(tempDir.path, 'calc.yaml')).writeAsStringSync(sidecar);

      final source = FilesystemSkillSource(tempDir);
      final skills = await source.loadAll();

      final pySkills = skills.whereType<PythonSkill>().toList();
      expect(pySkills, hasLength(1));
      expect(pySkills.first.metadata.name, 'calc');
      expect(pySkills.first.metadata.category, 'math');
    });

    test('returns empty list for non-existent directory', () async {
      final source = FilesystemSkillSource(
        Directory(p.join(tempDir.path, 'nope')),
      );
      final skills = await source.loadAll();
      expect(skills, isEmpty);
    });

    test('ignores non-.md/.py files', () async {
      File(p.join(tempDir.path, 'readme.txt')).writeAsStringSync('ignore me');

      final source = FilesystemSkillSource(tempDir);
      final skills = await source.loadAll();
      expect(skills, isEmpty);
    });
  });
}
