import 'dart:async';

import 'package:dart_monty_bridge/dart_monty_bridge.dart' as dmb;
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
  Duration? agentTimeout,
  Map<String, Stream<Object?> Function()>? streamFactories,
  String? prelude,
}) {
  return () async {
    final dfRegistry = DfRegistry();
    final streamRegistry = StreamRegistry();
    if (streamFactories != null) {
      for (final entry in streamFactories.entries) {
        streamRegistry.registerFactory(entry.key, entry.value);
      }
    }
    final platform = platformFactory != null ? await platformFactory() : null;
    final bridge = DefaultMontyBridge(
      platform: platform,
      useFutures: false,
      limits: limits ?? MontyLimitsDefaults.tool,
    );

    // Register IsolatePlugin if a platform factory is provided.
    // When LLM callbacks are available, children get oracle access via
    // childPluginRegistryFactory so that llm_complete() / llm_chat() work
    // inside spawned isolates.
    IsolatePlugin? isolatePlugin;
    if (platformFactory != null) {
      final childFactory = _buildChildPluginRegistryFactory(
        llmCompleter: llmCompleter,
        llmChatCompleter: llmChatCompleter,
        agentApi: agentApi,
        agentTimeout: agentTimeout,
      );
      isolatePlugin = IsolatePlugin(
        platformFactory: platformFactory,
        childPluginRegistryFactory: childFactory,
      );
      isolatePlugin.functions.forEach(bridge.register);
    }

    final registry = PluginRegistry();
    try {
      registry
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
        registry.register(
          AgentPlugin(
            agentApi: agentApi,
            agentTimeout: agentTimeout ?? const Duration(seconds: 30),
          ),
        );
      }
      if (llmCompleter != null && llmChatCompleter != null) {
        registry.register(
          LlmPlugin.fromCallbacks(
            complete: llmCompleter,
            chat: llmChatCompleter,
          ),
        );
      } else if (agentApi != null) {
        registry.register(
          LlmPlugin(
            agentApi: agentApi,
            agentTimeout: agentTimeout ?? const Duration(seconds: 30),
          ),
        );
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

    // Collect all host function schemas so the execute_python tool
    // description can tell the LLM what functions are available.
    final hostSchemas = <HostFunctionSchema>[
      for (final plugin in registry.plugins)
        for (final fn in plugin.functions) fn.schema,
      if (extraFunctions != null)
        for (final fn in extraFunctions) fn.schema,
    ];

    return MontyScriptEnvironment(
      bridge: bridge,
      ownedPlatform: platform,
      dfRegistry: dfRegistry,
      streamRegistry: streamRegistry,
      executionTimeout: executionTimeout,
      isolatePlugin: isolatePlugin,
      hostFunctionSchemas: hostSchemas,
      prelude: prelude,
    );
  };
}

/// Builds a [dmb.ChildPluginRegistryFactory] that gives each child isolate
/// an [LlmPlugin] wired to the same LLM callbacks (or [AgentApi]) as the
/// parent session.
///
/// Returns `null` when no LLM path is available, which means children will
/// run without oracle access (matching existing behaviour).
dmb.ChildPluginRegistryFactory? _buildChildPluginRegistryFactory({
  required LlmCompleter? llmCompleter,
  required LlmChatCompleter? llmChatCompleter,
  required AgentApi? agentApi,
  required Duration? agentTimeout,
}) {
  // Determine which LlmPlugin variant the child should get (same logic as
  // the parent registry).
  final hasCallbacks = llmCompleter != null && llmChatCompleter != null;
  if (!hasCallbacks && agentApi == null) return null;

  return () async {
    final childRegistry = dmb.PluginRegistry();
    if (hasCallbacks) {
      childRegistry.register(
        LlmPlugin.fromCallbacks(
          complete: llmCompleter,
          chat: llmChatCompleter,
        ),
      );
    } else {
      childRegistry.register(
        LlmPlugin(
          agentApi: agentApi!,
          agentTimeout: agentTimeout ?? const Duration(seconds: 30),
        ),
      );
    }
    return childRegistry;
  };
}
