import 'package:soliplex_agent/src/host/agent_api.dart';
import 'package:soliplex_agent/src/models/agent_result.dart';
import 'package:soliplex_agent/src/runtime/agent_runtime.dart';
import 'package:soliplex_agent/src/runtime/agent_session.dart';

/// Production [AgentApi] backed by an [AgentRuntime].
///
/// Maintains a handle table mapping integer handles to [AgentSession]s.
/// Each call to [spawnAgent] creates a new session and returns a unique
/// monotonically-increasing handle.
class RuntimeAgentApi implements AgentApi {
  /// Creates a [RuntimeAgentApi] wrapping [runtime].
  RuntimeAgentApi({required AgentRuntime runtime}) : _runtime = runtime;

  final AgentRuntime _runtime;
  final Map<int, AgentSession> _handles = {};
  int _nextHandle = 1;

  @override
  Future<int> spawnAgent(
    String roomId,
    String prompt, {
    Duration? timeout,
  }) async {
    final session = await _runtime.spawn(
      roomId: roomId,
      prompt: prompt,
      timeout: timeout,
    );
    final handle = _nextHandle++;
    _handles[handle] = session;
    return handle;
  }

  @override
  Future<List<String>> waitAll(List<int> handles, {Duration? timeout}) async {
    final sessions = handles.map(_lookupSession).toList();
    final results = await _runtime.waitAll(sessions, timeout: timeout);
    return results.map(_extractOutput).toList();
  }

  @override
  Future<String> getResult(int handle, {Duration? timeout}) async {
    final session = _lookupSession(handle);
    final result = await session.awaitResult(timeout: timeout);
    return _extractOutput(result);
  }

  @override
  Future<bool> cancelAgent(int handle) async {
    _lookupSession(handle).cancel();
    return true;
  }

  AgentSession _lookupSession(int handle) {
    final session = _handles[handle];
    if (session == null) {
      throw ArgumentError.value(handle, 'handle', 'Unknown agent handle');
    }
    return session;
  }

  static String _extractOutput(AgentResult result) => switch (result) {
        AgentSuccess(:final output) => output,
        AgentFailure(:final error) => throw StateError('Agent failed: $error'),
        AgentTimedOut(:final elapsed) => throw StateError(
            'Agent timed out after $elapsed',
          ),
      };
}
