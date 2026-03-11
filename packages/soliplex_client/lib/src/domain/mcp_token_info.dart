import 'package:meta/meta.dart';

/// MCP token with optional expiry information.
@immutable
class McpTokenInfo {
  /// Creates an MCP token info.
  const McpTokenInfo({
    required this.token,
    this.expiresIn,
  });

  /// The MCP token string.
  final String token;

  /// Token lifetime in seconds from issuance, if known.
  final int? expiresIn;
}
