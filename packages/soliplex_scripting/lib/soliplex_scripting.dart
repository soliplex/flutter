/// Wiring package bridging Monty interpreter events to ag-ui protocol.
library;

export 'package:soliplex_agent/soliplex_agent.dart' show ThreadKey;

export 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart'
    show
        HostFunction,
        HostFunctionSchema,
        HostParam,
        HostParamType,
        MontyLimitsDefaults,
        MontyPlugin;

export 'src/ag_ui_bridge_adapter.dart';
export 'src/df_functions.dart';
export 'src/host_schema_ag_ui.dart';
export 'src/monty_script_environment.dart';
export 'src/monty_script_environment_factory.dart';
export 'src/plugin_registry.dart';
export 'src/plugins/agent_plugin.dart';
export 'src/plugins/blackboard_plugin.dart';
export 'src/plugins/chart_plugin.dart';
export 'src/plugins/df_plugin.dart';
export 'src/plugins/form_plugin.dart';
export 'src/plugins/llm_plugin.dart';
export 'src/plugins/mcp_plugin.dart';
export 'src/plugins/platform_plugin.dart';
export 'src/plugins/stream_plugin.dart';
export 'src/python_executor_tool.dart';
export 'src/stream_registry.dart';
