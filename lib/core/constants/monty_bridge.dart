/// Monty bridge protocol version.
///
/// Sent as the [montyVersionHeader] header on AG-UI SSE connections.
/// The backend uses this to gate which auto-generated monty skills are
/// included in the agent context.
const int montyBridgeVersion = 1;

/// HTTP header name for the monty bridge version.
const String montyVersionHeader = 'X-Monty-Version';
