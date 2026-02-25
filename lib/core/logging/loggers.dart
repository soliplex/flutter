import 'package:soliplex_logging/soliplex_logging.dart';

/// Type-safe logging access.
///
/// Use these static loggers instead of creating new ones to ensure
/// consistent logger names across the codebase.
///
/// Example:
/// ```dart
/// Loggers.auth.info('User logged in');
/// Loggers.http.debug('GET /api/users');
/// Loggers.activeRun.error('Failed', error: e, stackTrace: s);
/// ```
///
/// Adding a new logger:
/// 1. Add a new static field here following the naming convention
/// 2. Document its purpose in the comment
/// 3. Update docs/logging-quickstart.md
abstract final class Loggers {
  /// Authentication events (login, logout, token refresh).
  static final auth = LogManager.instance.getLogger('Auth');

  /// HTTP request/response logging.
  static final http = LogManager.instance.getLogger('HTTP');

  /// AG-UI run processing events.
  static final activeRun = LogManager.instance.getLogger('ActiveRun');

  /// Chat feature events.
  static final chat = LogManager.instance.getLogger('Chat');

  /// Room feature events.
  static final room = LogManager.instance.getLogger('Room');

  /// Navigation/routing events.
  static final router = LogManager.instance.getLogger('Router');

  /// Quiz feature events.
  static final quiz = LogManager.instance.getLogger('Quiz');

  /// Configuration changes.
  static final config = LogManager.instance.getLogger('Config');

  /// General UI events.
  static final ui = LogManager.instance.getLogger('UI');

  /// Telemetry and backend log shipping events.
  static final telemetry = LogManager.instance.getLogger('Telemetry');

  /// Client-side tool execution orchestration.
  static final toolExecution = LogManager.instance.getLogger('ToolExecution');
}
