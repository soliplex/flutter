/// Wiring package bridging Monty interpreter events to ag-ui protocol.
library;

export 'package:soliplex_agent/soliplex_agent.dart' show ThreadKey;

export 'src/ag_ui_bridge_adapter.dart';
export 'src/bridge_cache.dart';
export 'src/host_function_wiring.dart';
export 'src/host_schema_ag_ui.dart';
export 'src/monty_tool_executor.dart';
export 'src/python_executor_tool.dart';
export 'src/scripting_tool_registry_resolver.dart';
