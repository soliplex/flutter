import 'package:soliplex_agent/soliplex_agent.dart' show BlackboardApi;
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

/// Plugin exposing shared blackboard read/write operations to Monty scripts.
class BlackboardPlugin extends MontyPlugin {
  BlackboardPlugin({required BlackboardApi blackboardApi})
      : _blackboardApi = blackboardApi;

  final BlackboardApi _blackboardApi;

  @override
  String get namespace => 'blackboard';

  @override
  List<HostFunction> get functions => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'blackboard_write',
            description: 'Write a value to the shared blackboard.',
            params: [
              HostParam(
                name: 'key',
                type: HostParamType.string,
                description: 'Key to write.',
              ),
              HostParam(
                name: 'value',
                type: HostParamType.any,
                isRequired: false,
                description: 'JSON-compatible value (string, number, '
                    'bool, list, map, or null).',
              ),
            ],
          ),
          handler: (args) async {
            final key = args['key']! as String;
            final value = args['value'];
            await _blackboardApi.write(key, value);
            return null;
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'blackboard_read',
            description: 'Read a value from the shared blackboard.',
            params: [
              HostParam(
                name: 'key',
                type: HostParamType.string,
                description: 'Key to read.',
              ),
            ],
          ),
          handler: (args) async {
            final key = args['key']! as String;
            return _blackboardApi.read(key);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'blackboard_keys',
            description: 'List all keys on the shared blackboard.',
          ),
          handler: (args) async {
            return _blackboardApi.keys();
          },
        ),
      ];
}
