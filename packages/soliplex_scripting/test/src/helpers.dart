import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

/// Records all [register] calls for verification.
class RecordingBridge implements MontyBridge {
  final registered = <HostFunction>[];
  final unregistered = <String>[];

  @override
  List<HostFunctionSchema> get schemas =>
      registered.map((f) => f.schema).toList();

  @override
  void register(HostFunction function) => registered.add(function);

  @override
  void unregister(String name) => unregistered.add(name);

  @override
  Stream<BridgeEvent> execute(String code) => const Stream.empty();

  @override
  void dispose() {}
}
