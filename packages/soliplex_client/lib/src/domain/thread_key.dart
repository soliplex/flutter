/// Fully qualified identifier for a conversation thread across servers.
///
/// The 3-tuple uniquely identifies a thread in a multi-server environment:
/// - `serverId`: which backend instance (e.g., 'staging.soliplex.io')
/// - `roomId`: which room / agent configuration
/// - `threadId`: which conversation thread within the room
///
/// Has value equality via Dart record semantics.
typedef ThreadKey = ({String serverId, String roomId, String threadId});
