/// Composite identifier for a room/thread pair.
///
/// Used as a type-safe map key with value equality throughout the codebase
/// wherever state is keyed by (roomId, threadId).
typedef ThreadKey = ({String roomId, String threadId});
