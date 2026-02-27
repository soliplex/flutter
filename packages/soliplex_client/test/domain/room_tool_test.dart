import 'package:soliplex_client/soliplex_client.dart';
import 'package:test/test.dart';

void main() {
  group('RoomTool', () {
    test('creates with all fields', () {
      const tool = RoomTool(
        name: 'rag_search',
        description: 'Search documents in the knowledge base',
        kind: 'search',
        toolRequires: 'tool_config',
        allowMcp: true,
        extraParameters: {'rag_lancedb_stem': '/data/rag'},
        aguiFeatureNames: ['feature1'],
      );

      expect(tool.name, equals('rag_search'));
      expect(
        tool.description,
        equals('Search documents in the knowledge base'),
      );
      expect(tool.kind, equals('search'));
      expect(tool.toolRequires, equals('tool_config'));
      expect(tool.allowMcp, isTrue);
      expect(
        tool.extraParameters,
        equals({'rag_lancedb_stem': '/data/rag'}),
      );
      expect(tool.aguiFeatureNames, equals(['feature1']));
    });

    test('creates with defaults', () {
      const tool = RoomTool(
        name: 'calculator',
        description: 'Perform calculations',
        kind: 'bare',
      );

      expect(tool.toolRequires, equals(''));
      expect(tool.allowMcp, isFalse);
      expect(tool.extraParameters, isEmpty);
      expect(tool.aguiFeatureNames, isEmpty);
    });

    test('toString includes name and kind', () {
      const tool = RoomTool(
        name: 'rag_search',
        description: 'Search',
        kind: 'search',
      );

      expect(tool.toString(), contains('rag_search'));
      expect(tool.toString(), contains('search'));
    });
  });
}
