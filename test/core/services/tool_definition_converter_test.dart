import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/services/tool_definition_converter.dart';

void main() {
  group('toolDefinitionToAgUiTool', () {
    test('maps backend fields to ag_ui Tool', () {
      final toolDef = <String, dynamic>{
        'tool_name': 'search',
        'tool_description': 'Search documents',
        'extra_parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string'},
          },
        },
      };

      final tool = toolDefinitionToAgUiTool(toolDef);

      expect(tool.name, equals('search'));
      expect(tool.description, equals('Search documents'));
      expect(tool.parameters, isA<Map<String, dynamic>>());
      final params = tool.parameters as Map;
      expect(params['type'], equals('object'));
    });

    test('defaults to empty strings for missing fields', () {
      final toolDef = <String, dynamic>{};

      final tool = toolDefinitionToAgUiTool(toolDef);

      expect(tool.name, equals(''));
      expect(tool.description, equals(''));
      expect(tool.parameters, isNull);
    });

    test('handles missing extra_parameters', () {
      final toolDef = <String, dynamic>{
        'tool_name': 'lookup',
        'tool_description': 'Lookup data',
      };

      final tool = toolDefinitionToAgUiTool(toolDef);

      expect(tool.name, equals('lookup'));
      expect(tool.description, equals('Lookup data'));
      expect(tool.parameters, isNull);
    });
  });

  group('roomToolsToAgUi', () {
    test('converts all valid tool definitions', () {
      const room = Room(
        id: 'room-1',
        name: 'Test',
        toolDefinitions: [
          {'tool_name': 'search', 'tool_description': 'Search'},
          {'tool_name': 'lookup', 'tool_description': 'Lookup'},
        ],
      );

      final tools = roomToolsToAgUi(room);

      expect(tools, hasLength(2));
      expect(tools[0].name, equals('search'));
      expect(tools[1].name, equals('lookup'));
    });

    test('filters out tools with empty names', () {
      const room = Room(
        id: 'room-1',
        name: 'Test',
        toolDefinitions: [
          {'tool_name': 'search', 'tool_description': 'Search'},
          {'tool_description': 'No name tool'},
          {'tool_name': '', 'tool_description': 'Empty name'},
        ],
      );

      final tools = roomToolsToAgUi(room);

      expect(tools, hasLength(1));
      expect(tools[0].name, equals('search'));
    });

    test('returns empty list for room without tools', () {
      const room = Room(id: 'room-1', name: 'Test');

      final tools = roomToolsToAgUi(room);

      expect(tools, isEmpty);
    });
  });
}
