import 'package:soliplex_agent/src/tools/tool_registry.dart';

/// Session-scoped scripting environment providing client-side tools.
///
/// Implementations own interpreter resources (bridge, registries) and
/// expose them as [ClientTool]s. The owning `AgentSession` calls
/// [dispose] when it tears down, cascading resource cleanup.
///
/// The runtime is completely agnostic about the interpreter technology
/// (WASM, Python subprocess, etc.) — it only sees [tools].
abstract interface class ScriptEnvironment {
  /// Client-side tools this environment provides (e.g., `execute_python`).
  List<ClientTool> get tools;

  /// Releases interpreter resources (bridge, registries).
  ///
  /// Called once by `AgentSession.dispose()`. Must be idempotent.
  void dispose();
}

/// Factory that creates a fresh [ScriptEnvironment] per session.
///
/// The closure captures app-level dependencies (HostApi, AgentApi,
/// MontyLimits, etc.) so callers only need to invoke it.
typedef ScriptEnvironmentFactory = Future<ScriptEnvironment> Function();
