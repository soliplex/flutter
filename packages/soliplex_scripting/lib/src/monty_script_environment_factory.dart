import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart'
    show MontyLimits;
import 'package:soliplex_agent/soliplex_agent.dart'
    show AgentApi, BlackboardApi, FormApi, HostApi, ScriptEnvironmentFactory;
import 'package:soliplex_client/soliplex_client.dart' show SoliplexHttpClient;
import 'package:soliplex_dataframe/soliplex_dataframe.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/src/host_function_wiring.dart';
import 'package:soliplex_scripting/src/monty_script_environment.dart';
import 'package:soliplex_scripting/src/stream_registry.dart';

/// Creates a [ScriptEnvironmentFactory] that produces session-scoped
/// [MontyScriptEnvironment] instances.
///
/// Each invocation of the returned factory creates a fresh bridge,
/// registers host functions once, and returns an environment that
/// disposes everything when the owning session dies.
///
/// ```dart
/// final factory = createMontyScriptEnvironmentFactory(
///   hostApi: myHostApi,
///   agentApi: myAgentApi,
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
  List<HostFunction>? extraFunctions,
  MontyPlatformFactory? platformFactory,
  MontyLimits? limits,
  Duration executionTimeout = const Duration(seconds: 30),
}) {
  return () async {
    final dfRegistry = DfRegistry();
    final streamRegistry = StreamRegistry();
    final bridge = DefaultMontyBridge(
      useFutures: false,
      limits: limits ?? MontyLimitsDefaults.tool,
    );

    // Register IsolatePlugin if a platform factory is provided.
    IsolatePlugin? isolatePlugin;
    if (platformFactory != null) {
      isolatePlugin = IsolatePlugin(platformFactory: platformFactory);
      isolatePlugin.functions.forEach(bridge.register);
    }

    HostFunctionWiring(
      hostApi: hostApi,
      agentApi: agentApi,
      blackboardApi: blackboardApi,
      httpClient: httpClient,
      getAuthToken: getAuthToken,
      dfRegistry: dfRegistry,
      streamRegistry: streamRegistry,
      formApi: formApi,
      extraFunctions: extraFunctions,
    ).registerOnto(bridge);
    return MontyScriptEnvironment(
      bridge: bridge,
      dfRegistry: dfRegistry,
      streamRegistry: streamRegistry,
      executionTimeout: executionTimeout,
      isolatePlugin: isolatePlugin,
    );
  };
}
