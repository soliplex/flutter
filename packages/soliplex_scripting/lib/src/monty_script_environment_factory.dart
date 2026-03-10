import 'dart:async';

import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart'
    show MontyLimits, MontyPlatform;
import 'package:soliplex_agent/soliplex_agent.dart'
    show AgentApi, BlackboardApi, FormApi, HostApi, ScriptEnvironmentFactory;
import 'package:soliplex_client/soliplex_client.dart' show SoliplexHttpClient;
import 'package:soliplex_dataframe/soliplex_dataframe.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/src/monty_script_environment.dart';
import 'package:soliplex_scripting/src/plugin_registry.dart';
import 'package:soliplex_scripting/src/plugins/agent_plugin.dart';
import 'package:soliplex_scripting/src/plugins/blackboard_plugin.dart';
import 'package:soliplex_scripting/src/plugins/chart_plugin.dart';
import 'package:soliplex_scripting/src/plugins/df_plugin.dart';
import 'package:soliplex_scripting/src/plugins/form_plugin.dart';
import 'package:soliplex_scripting/src/plugins/llm_plugin.dart';
import 'package:soliplex_scripting/src/plugins/mcp_plugin.dart';
import 'package:soliplex_scripting/src/plugins/platform_plugin.dart';
import 'package:soliplex_scripting/src/plugins/stream_plugin.dart';
import 'package:soliplex_scripting/src/stream_registry.dart';

/// Factory that creates a fresh [MontyPlatform] for each session.
typedef MontyPlatformFactory = Future<MontyPlatform> Function();

/// Creates a [ScriptEnvironmentFactory] that produces session-scoped
/// [MontyScriptEnvironment] instances.
///
/// Each invocation of the returned factory creates a fresh bridge,
/// registers plugins via [PluginRegistry], and returns an environment that
/// disposes everything when the owning session dies.
///
/// When [platformFactory] is provided, each session gets its own
/// [MontyPlatform] instance, enabling concurrent Monty execution
/// across sessions (e.g. parent + child agents). Without it, the
/// bridge falls back to the global [MontyPlatform.instance] singleton.
///
/// ```dart
/// final factory = createMontyScriptEnvironmentFactory(
///   hostApi: myHostApi,
///   agentApi: myAgentApi,
///   platformFactory: () async => MontyFfi(bindings: NativeBindingsFfi()),
/// );
/// final runtime = AgentRuntime(
///   // ...
///   scriptEnvironmentFactory: factory,
/// );
/// ```
ScriptEnvironmentFactory createMontyScriptEnvironmentFactory({
  required HostApi hostApi,
  AgentApi? agentApi,
  BlackboardApi? blackboardApi,
  SoliplexHttpClient? httpClient,
  String? Function()? getAuthToken,
  FormApi? formApi,
  McpToolExecutor? mcpExecutor,
  McpToolLister? mcpToolLister,
  McpServerLister? mcpServerLister,
  LlmCompleter? llmCompleter,
  LlmChatCompleter? llmChatCompleter,
  List<HostFunction>? extraFunctions,
  List<MontyPlugin>? extraPlugins,
  MontyPlatformFactory? platformFactory,
  MontyLimits? limits,
  Duration executionTimeout = const Duration(seconds: 30),
}) {
  return () async {
    final dfRegistry = DfRegistry();
    final streamRegistry = StreamRegistry();
    final platform = platformFactory != null ? await platformFactory() : null;
    final bridge = DefaultMontyBridge(
      platform: platform,
      useFutures: false,
      limits: limits ?? MontyLimitsDefaults.tool,
    );

    // Register IsolatePlugin if a platform factory is provided.
    IsolatePlugin? isolatePlugin;
    if (platformFactory != null) {
      isolatePlugin = IsolatePlugin(platformFactory: platformFactory);
      isolatePlugin.functions.forEach(bridge.register);
    }

    try {
      final registry = PluginRegistry()
        ..register(DfPlugin(dfRegistry: dfRegistry))
        ..register(ChartPlugin(hostApi: hostApi))
        ..register(
          PlatformPlugin(
            hostApi: hostApi,
            httpClient: httpClient,
            getAuthToken: getAuthToken,
          ),
        )
        ..register(StreamPlugin(streamRegistry: streamRegistry));
      if (formApi != null) {
        registry.register(FormPlugin(formApi: formApi));
      }
      if (agentApi != null) {
        registry.register(AgentPlugin(agentApi: agentApi));
      }
      if (llmCompleter != null && llmChatCompleter != null) {
        registry.register(
          LlmPlugin.fromCallbacks(
            complete: llmCompleter,
            chat: llmChatCompleter,
          ),
        );
      } else if (agentApi != null) {
        registry.register(LlmPlugin(agentApi: agentApi));
      }
      if (mcpExecutor != null) {
        registry.register(
          McpPlugin(
            executor: mcpExecutor,
            toolLister: mcpToolLister!,
            serverLister: mcpServerLister!,
          ),
        );
      }
      if (blackboardApi != null) {
        registry.register(BlackboardPlugin(blackboardApi: blackboardApi));
      }
      if (extraPlugins != null) {
        extraPlugins.forEach(registry.register);
      }
      await registry.attachTo(bridge, extraFunctions: extraFunctions);
    } on Object {
      bridge.dispose();
      if (platform != null) unawaited(platform.dispose());
      rethrow;
    }
    return MontyScriptEnvironment(
      bridge: bridge,
      ownedPlatform: platform,
      dfRegistry: dfRegistry,
      streamRegistry: streamRegistry,
      executionTimeout: executionTimeout,
      isolatePlugin: isolatePlugin,
    );
  };
}
