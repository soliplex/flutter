/// Illustrates how `ScriptingToolRegistryResolver` injects the
/// `execute_python` tool into an agent's tool registry.
///
/// This example is illustrative -- it shows the wiring pattern without
/// requiring a running backend or Monty WASM runtime.
library;

// ignore_for_file: unused_local_variable

import 'package:soliplex_scripting/soliplex_scripting.dart';

void main() {
  // 1. Create a bridge cache with a concurrency limit.
  final cache = BridgeCache(limit: 4);

  // 2. Wire host functions so Python can call back into Dart.
  //    (Requires a HostApi implementation from soliplex_agent.)
  // final wiring = HostFunctionWiring(hostApi: myHostApi);

  // 3. Create a tool executor for a specific thread.
  // final executor = MontyToolExecutor(
  //   threadKey: (serverId: 'default', roomId: 'r1', threadId: 't1'),
  //   bridgeCache: cache,
  //   hostWiring: wiring,
  // );

  // 4. Wrap the base tool resolver to transparently add execute_python.
  // final resolver = ScriptingToolRegistryResolver(
  //   inner: baseToolResolver,
  //   executor: executor,
  // );

  // The resolver can now be passed to AgentRuntime. When the LLM calls
  // execute_python, the MontyToolExecutor handles it automatically.
}
