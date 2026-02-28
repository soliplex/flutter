import 'package:soliplex_interpreter_monty/src/bridge/host_param_type.dart';
import 'package:soliplex_interpreter_monty/src/bridge/tool_definition_converter.dart';
import 'package:test/test.dart';

void main() {
  group('toolDefToHostSchema', () {
    test('converts tool def with kind, tool_name, tool_description', () {
      final toolDef = <String, dynamic>{
        'kind': 'get_current_datetime',
        'tool_name': 'soliplex.tools.get_current_datetime',
        'tool_description': 'Returns the current date and time',
        'extra_parameters': <String, dynamic>{},
      };

      final schema = toolDefToHostSchema(toolDef);

      expect(schema, isNotNull);
      expect(schema!.name, 'get_current_datetime');
      expect(schema.description, 'Returns the current date and time');
    });

    test('empty extra_parameters produces zero HostParams', () {
      final toolDef = <String, dynamic>{
        'kind': 'ping',
        'tool_name': 'soliplex.tools.ping',
        'tool_description': 'Ping',
        'extra_parameters': <String, dynamic>{},
      };

      final schema = toolDefToHostSchema(toolDef);

      expect(schema, isNotNull);
      expect(schema!.params, isEmpty);
    });

    test('null extra_parameters produces zero HostParams', () {
      final toolDef = <String, dynamic>{
        'kind': 'ping',
        'tool_name': 'soliplex.tools.ping',
        'tool_description': 'Ping',
      };

      final schema = toolDefToHostSchema(toolDef);

      expect(schema, isNotNull);
      expect(schema!.params, isEmpty);
    });

    test('returns null when kind is missing', () {
      final toolDef = <String, dynamic>{
        'tool_name': 'soliplex.tools.something',
        'tool_description': 'No kind',
      };

      expect(toolDefToHostSchema(toolDef), isNull);
    });

    test('returns null when kind is empty', () {
      final toolDef = <String, dynamic>{
        'kind': '',
        'tool_name': 'soliplex.tools.something',
        'tool_description': 'Empty kind',
      };

      expect(toolDefToHostSchema(toolDef), isNull);
    });

    test('parses JSON Schema properties with multiple types', () {
      final toolDef = <String, dynamic>{
        'kind': 'search',
        'tool_name': 'soliplex.tools.search',
        'tool_description': 'Search documents',
        'extra_parameters': {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'Search query',
            },
            'limit': {
              'type': 'integer',
              'description': 'Max results',
            },
            'threshold': {
              'type': 'number',
              'description': 'Score threshold',
            },
            'verbose': {
              'type': 'boolean',
              'description': 'Verbose output',
            },
            'tags': {
              'type': 'array',
              'description': 'Filter tags',
            },
            'options': {
              'type': 'object',
              'description': 'Extra options',
            },
          },
          'required': ['query'],
        },
      };

      final schema = toolDefToHostSchema(toolDef)!;

      expect(schema.params, hasLength(6));

      final paramMap = {for (final p in schema.params) p.name: p};
      expect(paramMap['query']!.type, HostParamType.string);
      expect(paramMap['query']!.isRequired, isTrue);
      expect(paramMap['query']!.description, 'Search query');

      expect(paramMap['limit']!.type, HostParamType.integer);
      expect(paramMap['limit']!.isRequired, isFalse);

      expect(paramMap['threshold']!.type, HostParamType.number);
      expect(paramMap['verbose']!.type, HostParamType.boolean);
      expect(paramMap['tags']!.type, HostParamType.list);
      expect(paramMap['options']!.type, HostParamType.map);
    });

    test('handles required vs optional params', () {
      final toolDef = <String, dynamic>{
        'kind': 'greet',
        'tool_name': 'soliplex.tools.greet',
        'tool_description': 'Greet user',
        'extra_parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'greeting': {'type': 'string'},
          },
          'required': ['name'],
        },
      };

      final schema = toolDefToHostSchema(toolDef)!;
      final paramMap = {for (final p in schema.params) p.name: p};

      expect(paramMap['name']!.isRequired, isTrue);
      expect(paramMap['greeting']!.isRequired, isFalse);
    });

    test('unknown JSON Schema type defaults to string', () {
      final toolDef = <String, dynamic>{
        'kind': 'weird',
        'tool_name': 'soliplex.tools.weird',
        'tool_description': 'Weird types',
        'extra_parameters': {
          'type': 'object',
          'properties': {
            'data': {'type': 'binary'},
          },
        },
      };

      final schema = toolDefToHostSchema(toolDef)!;
      expect(schema.params.first.type, HostParamType.string);
    });
  });

  group('jsonSchemaPropsToParams', () {
    test('maps properties and required set correctly', () {
      final properties = <String, dynamic>{
        'a': {'type': 'string', 'description': 'First'},
        'b': {'type': 'integer'},
      };

      final params = jsonSchemaPropsToParams(properties, {'a'});

      expect(params, hasLength(2));
      expect(params[0].name, 'a');
      expect(params[0].isRequired, isTrue);
      expect(params[0].description, 'First');
      expect(params[1].name, 'b');
      expect(params[1].isRequired, isFalse);
      expect(params[1].description, isNull);
    });

    test('handles empty properties', () {
      final params = jsonSchemaPropsToParams(<String, dynamic>{}, <String>{});
      expect(params, isEmpty);
    });
  });

  group('roomToolDefsToMappings', () {
    test('converts valid tool defs to mappings', () {
      final toolDefs = [
        <String, dynamic>{
          'kind': 'get_time',
          'tool_name': 'soliplex.tools.get_time',
          'tool_description': 'Get time',
          'extra_parameters': <String, dynamic>{},
        },
        <String, dynamic>{
          'kind': 'search',
          'tool_name': 'soliplex.tools.search',
          'tool_description': 'Search',
          'extra_parameters': {
            'type': 'object',
            'properties': {
              'query': {'type': 'string'},
            },
            'required': ['query'],
          },
        },
      ];

      final mappings = roomToolDefsToMappings(toolDefs);

      expect(mappings, hasLength(2));
      expect(mappings[0].pythonName, 'get_time');
      expect(mappings[0].registryName, 'soliplex.tools.get_time');
      expect(mappings[0].schema.params, isEmpty);

      expect(mappings[1].pythonName, 'search');
      expect(mappings[1].registryName, 'soliplex.tools.search');
      expect(mappings[1].schema.params, hasLength(1));
    });

    test('skips tools missing kind', () {
      final toolDefs = [
        <String, dynamic>{
          'tool_name': 'soliplex.tools.no_kind',
          'tool_description': 'Missing kind',
        },
      ];

      expect(roomToolDefsToMappings(toolDefs), isEmpty);
    });

    test('skips tools missing tool_name', () {
      final toolDefs = [
        <String, dynamic>{
          'kind': 'orphan',
          'tool_description': 'Missing tool_name',
        },
      ];

      expect(roomToolDefsToMappings(toolDefs), isEmpty);
    });

    test('filters invalid and converts valid in mixed list', () {
      final toolDefs = [
        <String, dynamic>{
          'kind': 'valid',
          'tool_name': 'soliplex.tools.valid',
          'tool_description': 'Valid',
        },
        <String, dynamic>{
          'tool_name': 'soliplex.tools.invalid',
        },
        <String, dynamic>{
          'kind': 'also_valid',
          'tool_name': 'soliplex.tools.also_valid',
          'tool_description': 'Also valid',
        },
      ];

      final mappings = roomToolDefsToMappings(toolDefs);

      expect(mappings, hasLength(2));
      expect(mappings[0].pythonName, 'valid');
      expect(mappings[1].pythonName, 'also_valid');
    });
  });
}
