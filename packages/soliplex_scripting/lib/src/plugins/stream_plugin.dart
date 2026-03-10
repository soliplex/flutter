import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/src/stream_registry.dart';

/// Plugin exposing stream subscription operations to Monty scripts.
class StreamPlugin extends MontyPlugin {
  StreamPlugin({required StreamRegistry streamRegistry})
      : _streamRegistry = streamRegistry;

  final StreamRegistry _streamRegistry;

  @override
  String get namespace => 'stream';

  @override
  List<HostFunction> get functions => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'stream_subscribe',
            description: 'Subscribe to a named data stream.',
            params: [
              HostParam(
                name: 'name',
                type: HostParamType.string,
                description: 'Stream name.',
              ),
            ],
          ),
          handler: (args) async {
            final name = args['name']! as String;
            return _streamRegistry.subscribe(name);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'stream_next',
            description: 'Pull the next value from a stream subscription.',
            params: [
              HostParam(
                name: 'handle',
                type: HostParamType.integer,
                description: 'Subscription handle.',
              ),
            ],
          ),
          handler: (args) async {
            final handle = (args['handle']! as num).toInt();
            return _streamRegistry.next(handle);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'stream_close',
            description: 'Close a stream subscription early.',
            params: [
              HostParam(
                name: 'handle',
                type: HostParamType.integer,
                description: 'Subscription handle.',
              ),
            ],
          ),
          handler: (args) async {
            final handle = (args['handle']! as num).toInt();
            return _streamRegistry.close(handle);
          },
        ),
      ];
}
