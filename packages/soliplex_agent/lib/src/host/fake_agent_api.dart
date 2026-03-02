import 'package:soliplex_agent/src/host/agent_api.dart';

/// In-memory [AgentApi] for testing.
///
/// Records all calls and returns configurable responses.
/// Pattern matches `FakeHostApi`.
class FakeAgentApi implements AgentApi {
  /// Creates a fake agent API with optional canned responses.
  FakeAgentApi({
    this.spawnResult = 1,
    this.waitAllResult = const [],
    this.getResultResult = '',
    this.cancelResult = true,
  });

  /// Value returned by [spawnAgent]. Increments after each call.
  int spawnResult;

  /// Value returned by [waitAll].
  List<String> waitAllResult;

  /// Value returned by [getResult].
  String getResultResult;

  /// Value returned by [cancelAgent].
  bool cancelResult;

  /// Recorded calls as `{methodName: [args]}`.
  final Map<String, List<Object?>> calls = {};

  @override
  Future<int> spawnAgent(
    String roomId,
    String prompt, {
    Duration? timeout,
  }) async {
    calls['spawnAgent'] = [roomId, prompt, timeout];
    return spawnResult++;
  }

  @override
  Future<List<String>> waitAll(List<int> handles, {Duration? timeout}) async {
    calls['waitAll'] = [handles, timeout];
    return waitAllResult;
  }

  @override
  Future<String> getResult(int handle, {Duration? timeout}) async {
    calls['getResult'] = [handle, timeout];
    return getResultResult;
  }

  @override
  Future<bool> cancelAgent(int handle) async {
    calls['cancelAgent'] = [handle];
    return cancelResult;
  }
}
