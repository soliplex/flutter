import 'package:meta/meta.dart';

/// A tool configured in a room.
@immutable
class RoomTool {
  /// Creates a room tool.
  const RoomTool({
    required this.name,
    required this.description,
    required this.kind,
    this.toolRequires = '',
    this.allowMcp = false,
    this.extraParameters = const {},
    this.aguiFeatureNames = const [],
  });

  /// Tool name as configured in the backend.
  final String name;

  /// Human-readable description of what the tool does.
  final String description;

  /// Tool kind (e.g., 'search', 'rag', 'bare').
  final String kind;

  /// What the tool requires to run (e.g., 'tool_config',
  /// 'fastapi_context', 'bare').
  final String toolRequires;

  /// Whether this tool is available via MCP.
  final bool allowMcp;

  /// Additional configuration parameters for the tool.
  final Map<String, dynamic> extraParameters;

  /// AG-UI feature names enabled for this tool.
  final List<String> aguiFeatureNames;

  @override
  String toString() => 'RoomTool(name: $name, kind: $kind)';
}
