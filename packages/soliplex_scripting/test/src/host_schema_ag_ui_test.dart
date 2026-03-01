import 'package:ag_ui/ag_ui.dart' show Tool;
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

void main() {
  group('HostSchemaAgUi.toAgUiTool', () {
    test('converts schema with params to Tool', () {
      const schema = HostFunctionSchema(
        name: 'search',
        description: 'Search documents',
        params: [
          HostParam(
            name: 'query',
            type: HostParamType.string,
            description: 'Search query',
          ),
          HostParam(
            name: 'limit',
            type: HostParamType.integer,
            isRequired: false,
          ),
        ],
      );

      final tool = schema.toAgUiTool();

      expect(tool, isA<Tool>());
      expect(tool.name, 'search');
      expect(tool.description, 'Search documents');

      final params = tool.parameters as Map<String, Object?>;
      expect(params['type'], 'object');

      final properties = params['properties']! as Map<String, Object?>;
      expect(properties.keys, containsAll(['query', 'limit']));

      final queryProp = properties['query']! as Map<String, Object?>;
      expect(queryProp['type'], 'string');
      expect(queryProp['description'], 'Search query');

      final limitProp = properties['limit']! as Map<String, Object?>;
      expect(limitProp['type'], 'integer');
      expect(limitProp.containsKey('description'), isFalse);

      final required = params['required']! as List<String>;
      expect(required, ['query']);
    });

    test('converts schema with no params', () {
      const schema = HostFunctionSchema(
        name: 'noop',
        description: 'Does nothing',
      );

      final tool = schema.toAgUiTool();

      expect(tool.name, 'noop');
      expect(tool.description, 'Does nothing');

      final params = tool.parameters as Map<String, Object?>;
      expect(params['type'], 'object');
      expect(params['properties'], <String, Object?>{});
      expect(params.containsKey('required'), isFalse);
    });

    test('includes all param types correctly', () {
      const schema = HostFunctionSchema(
        name: 'multi',
        description: 'Multi-type params',
        params: [
          HostParam(name: 's', type: HostParamType.string),
          HostParam(name: 'i', type: HostParamType.integer),
          HostParam(name: 'n', type: HostParamType.number),
          HostParam(name: 'b', type: HostParamType.boolean),
          HostParam(name: 'l', type: HostParamType.list),
          HostParam(name: 'm', type: HostParamType.map),
        ],
      );

      final tool = schema.toAgUiTool();
      final params = tool.parameters as Map<String, Object?>;
      final properties = params['properties']! as Map<String, Object?>;

      expect(
        (properties['s']! as Map)['type'],
        'string',
      );
      expect(
        (properties['i']! as Map)['type'],
        'integer',
      );
      expect(
        (properties['n']! as Map)['type'],
        'number',
      );
      expect(
        (properties['b']! as Map)['type'],
        'boolean',
      );
      expect(
        (properties['l']! as Map)['type'],
        'array',
      );
      expect(
        (properties['m']! as Map)['type'],
        'object',
      );
    });
  });
}
