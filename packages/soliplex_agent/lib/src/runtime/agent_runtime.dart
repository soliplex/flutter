import 'dart:async';

import 'package:soliplex_agent/src/host/platform_constraints.dart';
import 'package:soliplex_agent/src/models/agent_result.dart';
import 'package:soliplex_agent/src/models/thread_key.dart';
import 'package:soliplex_agent/src/run/run_orchestrator.dart';
import 'package:soliplex_agent/src/runtime/agent_session.dart';
import 'package:soliplex_agent/src/runtime/agent_session_state.dart';
import 'package:soliplex_agent/src/tools/tool_registry_resolver.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

/// Facade for spawning and coordinating multiple [AgentSession]s.
///
/// Each runtime is bound to a single backend server via [SoliplexApi].
/// The [serverId] identifies which server this runtime talks to and is
/// embedded into every [ThreadKey] created by [spawn].
///
/// ```dart
/// final runtime = AgentRuntime(
///   api: api,
///   agUiClient: agUiClient,
///   toolRegistryResolver: resolver,
///   platform: NativePlatformConstraints(),
///   logger: logger,
/// );
///
/// final session = await runtime.spawn(
///   roomId: 'weather',
///   prompt: 'Need umbrella?',
/// );
/// final result = await session.result;
/// ```
class AgentRuntime {
  AgentRuntime({
    required SoliplexApi api,
    required AgUiClient agUiClient,
    required ToolRegistryResolver toolRegistryResolver,
    required PlatformConstraints platform,
    required Logger logger,
    this.serverId = 'default',
  })  : _api = api,
        _agUiClient = agUiClient,
        _toolRegistryResolver = toolRegistryResolver,
        _platform = platform,
        _logger = logger;

  final SoliplexApi _api;
  final AgUiClient _agUiClient;
  final ToolRegistryResolver _toolRegistryResolver;
  final PlatformConstraints _platform;
  final Logger _logger;

  /// Identifies which backend server this runtime targets.
  final String serverId;

  final Map<String, AgentSession> _sessions = {};
  final Set<String> _deletedThreadIds = {};
  final StreamController<List<AgentSession>> _sessionController =
      StreamController<List<AgentSession>>.broadcast();
  bool _disposed = false;

  /// Currently tracked (non-disposed) sessions.
  List<AgentSession> get activeSessions =>
      List.unmodifiable(_sessions.values.toList());

  /// Emits whenever the active session list changes.
  Stream<List<AgentSession>> get sessionChanges => _sessionController.stream;

  /// Looks up a session by its [ThreadKey]. Returns `null` if not found.
  AgentSession? getSession(ThreadKey key) {
    return _sessions.values.where((s) => s.threadKey == key).firstOrNull;
  }

  /// Spawns a new agent session.
  ///
  /// Creates a thread (or reuses [threadId]), resolves tools for [roomId],
  /// builds an [AgentSession], and starts the run.
  Future<AgentSession> spawn({
    required String roomId,
    required String prompt,
    String? threadId,
    Duration? timeout,
    bool ephemeral = true,
  }) async {
    _guardNotDisposed();
    _guardWasmReentrancy();
    _guardConcurrency();
    final (key, existingRunId) = await _resolveThread(roomId, threadId);
    final session = await _buildSession(
      key: key,
      roomId: roomId,
      ephemeral: ephemeral,
    );
    _trackSession(session);
    await session.start(userMessage: prompt, existingRunId: existingRunId);
    _scheduleCompletion(session, timeout);
    return session;
  }

  /// Waits for all sessions to complete, collecting results.
  Future<List<AgentResult>> waitAll(
    List<AgentSession> sessions, {
    Duration? timeout,
  }) {
    return Future.wait(sessions.map((s) => s.awaitResult(timeout: timeout)));
  }

  /// Returns the first result from any of the given sessions.
  Future<AgentResult> waitAny(
    List<AgentSession> sessions, {
    Duration? timeout,
  }) {
    return Future.any(sessions.map((s) => s.awaitResult(timeout: timeout)));
  }

  /// Cancels all active sessions.
  Future<void> cancelAll() async {
    for (final session in _sessions.values.toList()) {
      session.cancel();
    }
  }

  /// Disposes the runtime and all sessions.
  ///
  /// Cancels active sessions, deletes ephemeral threads (swallowing
  /// errors), and closes the session stream.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await cancelAll();
    await _cleanupEphemeralThreads();
    for (final session in _sessions.values.toList()) {
      session.dispose();
    }
    _sessions.clear();
    unawaited(_sessionController.close());
  }

  // ---------------------------------------------------------------------------
  // Guards
  // ---------------------------------------------------------------------------

  void _guardNotDisposed() {
    if (_disposed) {
      throw StateError('AgentRuntime has been disposed');
    }
  }

  void _guardWasmReentrancy() {
    if (!_platform.supportsReentrantInterpreter && _activeCount > 0) {
      throw StateError('WASM runtime does not support concurrent sessions');
    }
  }

  void _guardConcurrency() {
    if (_activeCount >= _platform.maxConcurrentBridges) {
      throw StateError(
        'Concurrency limit reached '
        '($_activeCount / ${_platform.maxConcurrentBridges})',
      );
    }
  }

  int get _activeCount =>
      _sessions.values.where((s) => !s.state.isTerminal).length;

  // ---------------------------------------------------------------------------
  // Thread resolution
  // ---------------------------------------------------------------------------

  Future<(ThreadKey, String?)> _resolveThread(
    String roomId,
    String? threadId,
  ) async {
    if (threadId != null) {
      final key = (serverId: serverId, roomId: roomId, threadId: threadId);
      return (key, null);
    }
    final (threadInfo, _) = await _api.createThread(roomId);
    final key = (serverId: serverId, roomId: roomId, threadId: threadInfo.id);
    final existingRunId =
        threadInfo.hasInitialRun ? threadInfo.initialRunId : null;
    return (key, existingRunId);
  }

  // ---------------------------------------------------------------------------
  // Session building
  // ---------------------------------------------------------------------------

  Future<AgentSession> _buildSession({
    required ThreadKey key,
    required String roomId,
    required bool ephemeral,
  }) async {
    final toolRegistry = await _toolRegistryResolver(roomId);
    final orchestrator = RunOrchestrator(
      api: _api,
      agUiClient: _agUiClient,
      toolRegistry: toolRegistry,
      platformConstraints: _platform,
      logger: _logger,
    );
    return AgentSession(
      threadKey: key,
      ephemeral: ephemeral,
      orchestrator: orchestrator,
      toolRegistry: toolRegistry,
      logger: _logger,
    );
  }

  // ---------------------------------------------------------------------------
  // Session tracking
  // ---------------------------------------------------------------------------

  void _trackSession(AgentSession session) {
    _sessions[session.id] = session;
    _emitSessions();
  }

  void _removeSession(AgentSession session) {
    _sessions.remove(session.id);
    _emitSessions();
  }

  void _emitSessions() {
    if (!_sessionController.isClosed) {
      _sessionController.add(activeSessions);
    }
  }

  // ---------------------------------------------------------------------------
  // Completion scheduling
  // ---------------------------------------------------------------------------

  void _scheduleCompletion(AgentSession session, Duration? timeout) {
    final future = timeout != null
        ? session.awaitResult(timeout: timeout)
        : session.result;
    unawaited(
      future.then((_) async {
        if (_disposed) return;
        await _handleSessionComplete(session);
      }),
    );
  }

  Future<void> _handleSessionComplete(AgentSession session) async {
    if (session.ephemeral) {
      await _deleteThreadSafe(session.threadKey);
    }
    _removeSession(session);
  }

  // ---------------------------------------------------------------------------
  // Ephemeral cleanup
  // ---------------------------------------------------------------------------

  Future<void> _cleanupEphemeralThreads() async {
    final ephemeral = _sessions.values.where((s) => s.ephemeral).toList();
    for (final session in ephemeral) {
      await _deleteThreadSafe(session.threadKey);
    }
  }

  Future<void> _deleteThreadSafe(ThreadKey key) async {
    if (!_deletedThreadIds.add(key.threadId)) return;
    try {
      await _api.deleteThread(key.roomId, key.threadId);
    } on Object catch (error) {
      _logger.warning('Failed to delete thread ${key.threadId}', error: error);
    }
  }
}

/// Extension to check terminal states on [AgentSessionState].
extension _AgentSessionStateX on AgentSessionState {
  bool get isTerminal =>
      this == AgentSessionState.completed ||
      this == AgentSessionState.failed ||
      this == AgentSessionState.cancelled;
}
