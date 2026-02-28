import 'package:soliplex_interpreter_monty/src/bridge/host_function.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_function_schema.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_param.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_param_type.dart';
import 'package:test/test.dart';

void main() {
  group('HostFunction', () {
    test('pairs schema with handler', () async {
      final fn = HostFunction(
        schema: const HostFunctionSchema(
          name: 'greet',
          description: 'Greet by name',
          params: [
            HostParam(name: 'name', type: HostParamType.string),
          ],
        ),
        handler: (args) async => 'Hello, ${args['name']}!',
      );

      expect(fn.schema.name, 'greet');

      final result = await fn.handler({'name': 'Alice'});
      expect(result, 'Hello, Alice!');
    });

    test('handler can return null', () async {
      final fn = HostFunction(
        schema: const HostFunctionSchema(
          name: 'log',
          description: 'Log a message',
          params: [
            HostParam(name: 'msg', type: HostParamType.string),
          ],
        ),
        handler: (args) async => null,
      );

      final result = await fn.handler({'msg': 'test'});
      expect(result, isNull);
    });
  });
}
