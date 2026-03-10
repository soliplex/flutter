import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

/// Executes an MCP tool call on a named server. Injected by the host app.
typedef McpToolExecutor = Future<Map<String, Object?>> Function(
  String serverId,
  String toolName,
  Map<String, Object?> args,
);

/// Lists available MCP tools, optionally filtered by server. Injected by
/// the host app.
typedef McpToolLister = Future<List<Map<String, Object?>>> Function({
  String? serverId,
});

/// Lists connected MCP servers. Injected by the host app.
typedef McpServerLister = Future<List<Map<String, Object?>>> Function();

/// Plugin exposing MCP (Model Context Protocol) tool discovery and
/// invocation to Monty scripts.
///
/// All transport and connection logic is injected via the three typedefs
/// above, keeping `soliplex_scripting` free of `dart:io` imports and
/// WASM-compatible.
class McpPlugin extends MontyPlugin {
  McpPlugin({
    required McpToolExecutor executor,
    required McpToolLister toolLister,
    required McpServerLister serverLister,
  })  : _executor = executor,
        _toolLister = toolLister,
        _serverLister = serverLister;

  final McpToolExecutor _executor;
  final McpToolLister _toolLister;
  final McpServerLister _serverLister;

  @override
  String get namespace => 'mcp';

  @override
  String? get systemPromptContext =>
      'MCP (Model Context Protocol) functions for calling external tools. '
      'Use mcp_list_tools() to discover, mcp_call_tool() to invoke.';

  @override
  List<HostFunction> get functions => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'mcp_call_tool',
            description: 'Call a tool on an MCP server. Returns the tool '
                'result as a dict with "isError" and "content" keys.',
            params: [
              HostParam(
                name: 'server',
                type: HostParamType.string,
                description: 'MCP server ID.',
              ),
              HostParam(
                name: 'tool',
                type: HostParamType.string,
                description: 'Tool name to invoke.',
              ),
              HostParam(
                name: 'args',
                type: HostParamType.map,
                isRequired: false,
                description: 'Arguments for the tool call.',
              ),
            ],
          ),
          handler: (args) async {
            final server = args['server']! as String;
            final tool = args['tool']! as String;
            final rawArgs = args['args'] as Map?;
            final toolArgs = rawArgs != null
                ? Map<String, Object?>.from(rawArgs)
                : <String, Object?>{};
            return _executor(server, tool, toolArgs);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'mcp_list_tools',
            description: 'List available tools from MCP servers. '
                'Returns a list of dicts with "server", "name", and '
                '"description" keys.',
            params: [
              HostParam(
                name: 'server',
                type: HostParamType.string,
                isRequired: false,
                description: 'Filter by server ID. Omit to list all servers.',
              ),
            ],
          ),
          handler: (args) async {
            final server = args['server'] as String?;
            return _toolLister(serverId: server);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'mcp_list_servers',
            description: 'List connected MCP servers. Returns a list of '
                'dicts with "id", "kind", and "status" keys.',
          ),
          handler: (args) async {
            return _serverLister();
          },
        ),
      ];
}
