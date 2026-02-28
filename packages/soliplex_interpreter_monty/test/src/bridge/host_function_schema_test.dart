import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_function_schema.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_param.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_param_type.dart';
import 'package:test/test.dart';

void main() {
  group('HostFunctionSchema.mapAndValidate', () {
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
          defaultValue: 10,
        ),
      ],
    );

    test('maps positional args by schema order', () {
      const pending = MontyPending(
        functionName: 'search',
        arguments: ['hello', 5],
        callId: 1,
      );

      final result = schema.mapAndValidate(pending);
      expect(result, {'query': 'hello', 'limit': 5});
    });

    test('maps kwargs by name', () {
      const pending = MontyPending(
        functionName: 'search',
        arguments: [],
        kwargs: {'query': 'hello', 'limit': 5},
        callId: 1,
      );

      final result = schema.mapAndValidate(pending);
      expect(result, {'query': 'hello', 'limit': 5});
    });

    test('kwargs overlay positional args', () {
      const pending = MontyPending(
        functionName: 'search',
        arguments: ['original'],
        kwargs: {'query': 'overridden'},
        callId: 1,
      );

      final result = schema.mapAndValidate(pending);
      expect(result['query'], 'overridden');
    });

    test('uses default for missing optional param', () {
      const pending = MontyPending(
        functionName: 'search',
        arguments: ['hello'],
        callId: 1,
      );

      final result = schema.mapAndValidate(pending);
      expect(result['query'], 'hello');
      expect(result['limit'], 10);
    });

    test('throws on missing required param', () {
      const pending = MontyPending(
        functionName: 'search',
        arguments: [],
        callId: 1,
      );

      expect(
        () => schema.mapAndValidate(pending),
        throwsArgumentError,
      );
    });

    test('throws on type mismatch', () {
      const pending = MontyPending(
        functionName: 'search',
        arguments: [42],
        callId: 1,
      );

      expect(
        () => schema.mapAndValidate(pending),
        throwsArgumentError,
      );
    });
  });

  group('HostFunctionSchema with no params', () {
    const schema = HostFunctionSchema(
      name: 'noop',
      description: 'Does nothing',
    );

    test('accepts empty args', () {
      const pending = MontyPending(
        functionName: 'noop',
        arguments: [],
        callId: 1,
      );

      expect(schema.mapAndValidate(pending), <String, Object?>{});
    });
  });

  group('HostFunctionSchema.toAgUiTool', () {
    test('exports correct Tool shape', () {
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
            defaultValue: 10,
            description: 'Max results',
          ),
        ],
      );

      final tool = schema.toAgUiTool();
      expect(tool.name, 'search');
      expect(tool.description, 'Search documents');

      final params = tool.parameters as Map<String, Object?>;
      expect(params['type'], 'object');

      final props = params['properties']! as Map<String, Object?>;
      expect(props['query'], {'type': 'string', 'description': 'Search query'});
      expect(
        props['limit'],
        {'type': 'integer', 'description': 'Max results'},
      );

      expect(params['required'], ['query']);
    });

    test('omits required key when no required params', () {
      const schema = HostFunctionSchema(
        name: 'optional_only',
        description: 'All optional',
        params: [
          HostParam(
            name: 'flag',
            type: HostParamType.boolean,
            isRequired: false,
          ),
        ],
      );

      final tool = schema.toAgUiTool();
      final params = tool.parameters as Map<String, Object?>;
      expect(params.containsKey('required'), isFalse);
    });

    test('handles no-param schema', () {
      const schema = HostFunctionSchema(
        name: 'ping',
        description: 'Ping',
      );

      final tool = schema.toAgUiTool();
      final params = tool.parameters as Map<String, Object?>;
      expect(params['properties'], <String, Object?>{});
      expect(params.containsKey('required'), isFalse);
    });
  });
}
