import 'package:soliplex_logging/soliplex_logging.dart' as sl;
import 'package:struct_log/struct_log.dart' as stl;

/// Adapter that forwards [stl.LogRecord]s from `struct_log` into the
/// `soliplex_logging` [sl.LogManager].
///
/// Register with `stl.LogManager.instance.addSink(StructLogBridgeSink())` to
/// route all dart_monty_bridge / PluginRegistry logs into the TUI's log file
/// and any other soliplex sinks.
class StructLogBridgeSink implements stl.LogSink {
  /// Creates a bridge sink that writes to the given [sl.LogManager].
  ///
  /// Defaults to [sl.LogManager.instance].
  StructLogBridgeSink({sl.LogManager? target})
      : _target = target ?? sl.LogManager.instance;

  final sl.LogManager _target;

  @override
  void write(stl.LogRecord record) {
    _target.emit(
      sl.LogRecord(
        level: _mapLevel(record.level),
        message: record.message,
        timestamp: record.timestamp,
        loggerName: 'monty.${record.loggerName}',
        error: record.error,
        stackTrace: record.stackTrace,
        spanId: record.spanId,
        traceId: record.traceId,
        attributes: record.attributes,
      ),
    );
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}

  static sl.LogLevel _mapLevel(stl.LogLevel level) => switch (level) {
        stl.LogLevel.trace => sl.LogLevel.trace,
        stl.LogLevel.debug => sl.LogLevel.debug,
        stl.LogLevel.info => sl.LogLevel.info,
        stl.LogLevel.warning => sl.LogLevel.warning,
        stl.LogLevel.error => sl.LogLevel.error,
        stl.LogLevel.fatal => sl.LogLevel.fatal,
      };
}
