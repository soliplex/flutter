/// Interface for spawning and managing L2 sub-agents from Python.
///
/// Parallel to `HostApi` (which handles platform/UI concerns), this
/// interface handles agent orchestration. Implementations bridge to
/// `AgentRuntime` (production) or record calls (testing).
abstract interface class AgentApi {
  /// Spawns a new agent in [roomId] with the given [prompt].
  ///
  /// Returns an integer handle for tracking the agent session.
  Future<int> spawnAgent(String roomId, String prompt, {Duration? timeout});

  /// Waits for all agents identified by [handles] to complete.
  ///
  /// Returns their output texts in the same order as [handles].
  Future<List<String>> waitAll(List<int> handles, {Duration? timeout});

  /// Returns the output text for a completed agent [handle].
  Future<String> getResult(int handle, {Duration? timeout});

  /// Cancels the agent identified by [handle].
  ///
  /// Returns `true` if the agent was successfully cancelled.
  Future<bool> cancelAgent(int handle);
}
