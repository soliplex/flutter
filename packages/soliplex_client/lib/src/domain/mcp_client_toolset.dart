import 'package:meta/meta.dart';

/// An MCP client toolset configured in a room.
///
/// Represents an external MCP server that the room connects to
/// as a client.
@immutable
class McpClientToolset {
  /// Creates an MCP client toolset.
  const McpClientToolset({
    required this.kind,
    this.allowedTools,
    this.toolsetParams = const {},
  });

  /// Transport kind (e.g., 'stdio', 'http').
  final String kind;

  /// Tools allowed from this toolset. Null means all tools are
  /// allowed; empty list means no tools are allowed.
  final List<String>? allowedTools;

  /// Transport parameters (e.g., url for http, command for stdio).
  final Map<String, dynamic> toolsetParams;

  @override
  String toString() => 'McpClientToolset(kind: $kind)';
}
