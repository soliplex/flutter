import 'package:meta/meta.dart';

/// Transport kind for an MCP server connection.
enum McpTransportKind {
  /// Process-based communication via stdin/stdout.
  stdio,

  /// HTTP-based streamable transport.
  http,
}

/// Configuration for connecting to a single MCP server.
@immutable
class McpServerConfig {
  const McpServerConfig.stdio({
    required this.command,
    this.args = const [],
    this.workingDirectory,
    this.environment,
  })  : kind = McpTransportKind.stdio,
        url = null;

  const McpServerConfig.http({required String this.url})
      : kind = McpTransportKind.http,
        command = null,
        args = const [],
        workingDirectory = null,
        environment = null;

  final McpTransportKind kind;

  /// Command to launch the MCP server process (stdio only).
  final String? command;

  /// Arguments for the server process (stdio only).
  final List<String> args;

  /// Working directory for the server process (stdio only).
  final String? workingDirectory;

  /// Environment variables for the server process (stdio only).
  final Map<String, String>? environment;

  /// URL for HTTP transport.
  final String? url;
}
