/// Illustrates how `MontyScriptEnvironment` provides `execute_python`
/// as a session-scoped tool via `ScriptEnvironmentFactory`.
///
/// This example is illustrative -- it shows the wiring pattern without
/// requiring a running backend or Monty WASM runtime.
library;

void main() {
  // 1. Create a ScriptEnvironmentFactory that produces session-scoped
  //    environments. Each invocation creates a fresh bridge + registries.
  //
  // final factory = createMontyScriptEnvironmentFactory(
  //   hostApi: myHostApi,
  //   agentApi: myAgentApi,  // optional, enables spawn_agent/ask_llm
  // );

  // 2. Pass the factory to AgentRuntime via wrapScriptEnvironmentFactory().
  //    Each session gets its own MontyScriptEnvironment with an isolated
  //    bridge. When the session ends, the environment is disposed.
  //
  // final runtime = AgentRuntime(
  //   connection: connection,
  //   toolRegistryResolver: resolver,
  //   extensionFactory: wrapScriptEnvironmentFactory(factory),
  //   platform: NativePlatformConstraints(),
  //   logger: logger,
  // );
}
