/// Illustrates how to create a `DefaultMontyBridge` and execute Python code.
///
/// This example is illustrative -- running it requires a `MontyPlatform`
/// implementation backed by the Monty WASM runtime.
library;

// ignore_for_file: unused_local_variable

import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

Future<void> main() async {
  // 1. Create a bridge (requires a MontyPlatform implementation).
  // final bridge = DefaultMontyBridge(platform: myMontyPlatform);

  // 2. Optionally register host functions so Python can call Dart.
  // final registry = HostFunctionRegistry();
  // registry.registerOnto(bridge);

  // 3. Execute Python code and listen for bridge events.
  // final events = bridge.execute('print("Hello from Monty!")');
  // await for (final event in events) {
  //   switch (event) {
  //     case BridgeTextContent(:final text):
  //       print('Output: $text');
  //     case BridgeRunFinished():
  //       print('Execution complete.');
  //     default:
  //       break;
  //   }
  // }

  // 4. For simple execution, MontyExecutionService wraps the loop:
  // final service = MontyExecutionService(bridge: bridge);
  // final result = await service.execute('2 + 2');
  // print('Result: ${result.returnValue}');
}
