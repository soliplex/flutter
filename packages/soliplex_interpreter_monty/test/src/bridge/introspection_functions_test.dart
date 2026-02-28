import 'dart:convert';

import 'package:soliplex_interpreter_monty/src/bridge/host_function_schema.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_param.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_param_type.dart';
import 'package:soliplex_interpreter_monty/src/bridge/introspection_functions.dart';
import 'package:test/test.dart';

/// Decodes a JSON string handler result into a typed map.
Map<String, Object?> _decode(Object? result) =>
    jsonDecode(result! as String) as Map<String, Object?>;

void main() {
  group('buildIntrospectionFunctions', () {
    test('returns exactly 2 functions with correct names', () {
      final fns = buildIntrospectionFunctions({});

      expect(fns, hasLength(2));
      expect(fns[0].schema.name, 'list_functions');
      expect(fns[1].schema.name, 'help');
    });
  });

  group('list_functions', () {
    test('returns categories with metadata', () async {
      final schemas = {
        'tools': [
          const HostFunctionSchema(
            name: 'search',
            description: 'Search docs',
            params: [
              HostParam(
                name: 'query',
                type: HostParamType.string,
                description: 'Search query',
              ),
            ],
          ),
        ],
      };

      final fns = buildIntrospectionFunctions(schemas);
      final decoded = _decode(await fns[0].handler({}));
      final tools = decoded['tools']! as Map<String, Object?>;

      // Has both registered + introspection categories.
      expect(tools.keys, containsAll(['tools', 'introspection']));

      // Registered category has search function.
      final toolsList = tools['tools']! as List<Object?>;
      expect(toolsList, hasLength(1));

      final searchEntry = toolsList[0]! as Map<String, Object?>;
      expect(searchEntry['name'], 'search');
      expect(searchEntry['description'], 'Search docs');

      final params = searchEntry['params']! as List<Object?>;
      expect(params, hasLength(1));

      final paramEntry = params[0]! as Map<String, Object?>;
      expect(paramEntry['name'], 'query');
      expect(paramEntry['type'], 'string');
      expect(paramEntry['required'], true);
      expect(paramEntry['description'], 'Search query');
    });

    test('includes introspection self-entry', () async {
      final fns = buildIntrospectionFunctions({});
      final decoded = _decode(await fns[0].handler({}));
      final tools = decoded['tools']! as Map<String, Object?>;
      final introList = tools['introspection']! as List<Object?>;

      expect(introList, hasLength(2));
      final names =
          introList.cast<Map<String, Object?>>().map((e) => e['name']).toList();
      expect(names, ['list_functions', 'help']);
    });

    test('empty registry returns only introspection', () async {
      final fns = buildIntrospectionFunctions({});
      final decoded = _decode(await fns[0].handler({}));
      final tools = decoded['tools']! as Map<String, Object?>;

      expect(tools.keys, ['introspection']);
    });
  });

  group('help', () {
    test('returns detail for known function', () async {
      final schemas = {
        'tools': [
          const HostFunctionSchema(
            name: 'search',
            description: 'Search docs',
            params: [
              HostParam(
                name: 'query',
                type: HostParamType.string,
                description: 'Search query',
              ),
            ],
          ),
        ],
      };

      final fns = buildIntrospectionFunctions(schemas);
      final decoded = _decode(await fns[1].handler({'name': 'search'}));

      expect(decoded['name'], 'search');
      expect(decoded['description'], 'Search docs');

      final params = decoded['params']! as List<Object?>;
      expect(params, hasLength(1));
    });

    test('returns detail for introspection function', () async {
      final fns = buildIntrospectionFunctions({});
      final decoded = _decode(await fns[1].handler({'name': 'list_functions'}));

      expect(decoded['name'], 'list_functions');
      expect(decoded['description'], isNotEmpty);
    });

    test('returns error string for unknown function', () async {
      final fns = buildIntrospectionFunctions({});
      final result = (await fns[1].handler({'name': 'nonexistent'}))! as String;

      expect(result, 'Unknown function: nonexistent');
    });
  });
}
