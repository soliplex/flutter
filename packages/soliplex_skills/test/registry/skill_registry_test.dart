import 'package:soliplex_skills/soliplex_skills.dart';
import 'package:test/test.dart';

void main() {
  const mdMeta = SkillMetadata(
    name: 'prompt-a',
    description: 'A prompt',
    category: 'prompts',
  );
  const pyMeta = SkillMetadata(
    name: 'script-b',
    description: 'A script',
    category: 'scripts',
  );
  const mdSkill = MarkdownSkill(
    metadata: mdMeta,
    sourcePath: '/a.md',
    content: 'body',
  );
  const pySkill = PythonSkill(
    metadata: pyMeta,
    sourcePath: '/b.py',
    code: 'x = 1',
  );

  group('SkillRegistry', () {
    test('starts empty', () {
      const registry = SkillRegistry();
      expect(registry.isEmpty, isTrue);
      expect(registry.length, 0);
      expect(registry.all, isEmpty);
    });

    test('register returns new instance with skill', () {
      const registry = SkillRegistry();
      final updated = registry.register(mdSkill);

      expect(registry.isEmpty, isTrue);
      expect(updated.length, 1);
      expect(updated.contains('prompt-a'), isTrue);
    });

    test('registerAll adds multiple skills', () {
      const registry = SkillRegistry();
      final updated = registry.registerAll([mdSkill, pySkill]);

      expect(updated.length, 2);
      expect(updated.contains('prompt-a'), isTrue);
      expect(updated.contains('script-b'), isTrue);
    });

    test('lookup returns registered skill', () {
      final registry = const SkillRegistry().register(mdSkill);
      final found = registry.lookup('prompt-a');
      expect(found, equals(mdSkill));
    });

    test('lookup throws for missing skill', () {
      const registry = SkillRegistry();
      expect(() => registry.lookup('nope'), throwsStateError);
    });

    test('tryLookup returns null for missing skill', () {
      const registry = SkillRegistry();
      expect(registry.tryLookup('nope'), isNull);
    });

    test('markdownSkills filters correctly', () {
      final registry = const SkillRegistry().registerAll([mdSkill, pySkill]);
      expect(registry.markdownSkills, [mdSkill]);
    });

    test('pythonSkills filters correctly', () {
      final registry = const SkillRegistry().registerAll([mdSkill, pySkill]);
      expect(registry.pythonSkills, [pySkill]);
    });

    test('byCategory filters correctly', () {
      final registry = const SkillRegistry().registerAll([mdSkill, pySkill]);
      expect(registry.byCategory('prompts'), [mdSkill]);
      expect(registry.byCategory('scripts'), [pySkill]);
      expect(registry.byCategory('other'), isEmpty);
    });

    test('later registration overwrites earlier by name', () {
      const updated = MarkdownSkill(
        metadata: mdMeta,
        sourcePath: '/a-v2.md',
        content: 'updated',
      );
      final registry =
          const SkillRegistry().register(mdSkill).register(updated);

      expect(registry.length, 1);
      expect((registry.lookup('prompt-a') as MarkdownSkill).content, 'updated');
    });
  });

  group('loadSkillRegistry', () {
    test('loads from multiple sources', () async {
      final source1 = _InMemorySource([mdSkill]);
      final source2 = _InMemorySource([pySkill]);

      final (registry, errors) = await loadSkillRegistry([source1, source2]);

      expect(errors, isEmpty);
      expect(registry.length, 2);
    });

    test('collects errors without throwing', () async {
      final good = _InMemorySource([mdSkill]);
      final bad = _FailingSource();

      final (registry, errors) = await loadSkillRegistry([good, bad]);

      expect(registry.length, 1);
      expect(errors, hasLength(1));
    });
  });
}

class _InMemorySource implements SkillSource {
  _InMemorySource(this._skills);
  final List<Skill> _skills;

  @override
  Future<List<Skill>> loadAll() async => _skills;
}

class _FailingSource implements SkillSource {
  @override
  Future<List<Skill>> loadAll() async =>
      throw const SkillLoadException('test', 'boom');
}
