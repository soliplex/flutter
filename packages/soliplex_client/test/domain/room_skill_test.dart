import 'package:soliplex_client/soliplex_client.dart';
import 'package:test/test.dart';

void main() {
  group('RoomSkill', () {
    test('creates with required fields only', () {
      const skill = RoomSkill(name: 'search', description: 'Search docs');

      expect(skill.name, equals('search'));
      expect(skill.description, equals('Search docs'));
      expect(skill.source, isNull);
      expect(skill.license, isNull);
      expect(skill.compatibility, isNull);
      expect(skill.allowedTools, isNull);
      expect(skill.stateNamespace, isNull);
      expect(skill.metadata, isEmpty);
      expect(skill.stateTypeSchema, isNull);
    });

    test('creates with all fields', () {
      const skill = RoomSkill(
        name: 'rag_search',
        description: 'Search knowledge base',
        source: 'filesystem',
        license: 'MIT',
        compatibility: '>=1.0',
        allowedTools: 'tool_a tool_b',
        stateNamespace: 'rag',
        metadata: {'author': 'test'},
        stateTypeSchema: {'type': 'object'},
      );

      expect(skill.name, equals('rag_search'));
      expect(skill.description, equals('Search knowledge base'));
      expect(skill.source, equals('filesystem'));
      expect(skill.license, equals('MIT'));
      expect(skill.compatibility, equals('>=1.0'));
      expect(skill.allowedTools, equals('tool_a tool_b'));
      expect(skill.stateNamespace, equals('rag'));
      expect(skill.metadata, equals({'author': 'test'}));
      expect(skill.stateTypeSchema, equals({'type': 'object'}));
    });

    test('toString includes name and source', () {
      const skill = RoomSkill(
        name: 'search',
        description: 'Search',
        source: 'filesystem',
      );

      expect(skill.toString(), contains('search'));
      expect(skill.toString(), contains('filesystem'));
    });
  });
}
