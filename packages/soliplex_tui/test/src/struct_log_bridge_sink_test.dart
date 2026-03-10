import 'package:soliplex_logging/soliplex_logging.dart' as sl;
import 'package:soliplex_tui/src/struct_log_bridge_sink.dart';
import 'package:struct_log/struct_log.dart' as stl;
import 'package:test/test.dart';

void main() {
  group('StructLogBridgeSink', () {
    late sl.LogManager slManager;
    late _CaptureSink capture;

    setUp(() {
      slManager = sl.LogManager.instance..reset();
      capture = _CaptureSink();
      slManager
        ..minimumLevel = sl.LogLevel.trace
        ..addSink(capture);
    });

    tearDown(() {
      slManager.reset();
      stl.LogManager.instance.reset();
    });

    test('forwards struct_log records to soliplex_logging', () {
      final bridge = StructLogBridgeSink(target: slManager);
      stl.LogManager.instance
        ..minimumLevel = stl.LogLevel.trace
        ..addSink(bridge);

      stl.LogManager.instance.getLogger('Bridge').info('hello from struct_log');

      expect(capture.records, hasLength(1));
      expect(capture.records.first.message, 'hello from struct_log');
      expect(capture.records.first.loggerName, 'monty.Bridge');
      expect(capture.records.first.level, sl.LogLevel.info);
    });

    test('maps all log levels correctly', () {
      final bridge = StructLogBridgeSink(target: slManager);
      stl.LogManager.instance
        ..minimumLevel = stl.LogLevel.trace
        ..addSink(bridge);

      stl.LogManager.instance.getLogger('Levels')
        ..trace('t')
        ..debug('d')
        ..info('i')
        ..warning('w')
        ..error('e')
        ..fatal('f');

      expect(capture.records.map((r) => r.level).toList(), [
        sl.LogLevel.trace,
        sl.LogLevel.debug,
        sl.LogLevel.info,
        sl.LogLevel.warning,
        sl.LogLevel.error,
        sl.LogLevel.fatal,
      ]);
    });

    test('preserves error, stackTrace, and attributes', () {
      final bridge = StructLogBridgeSink(target: slManager);
      stl.LogManager.instance
        ..minimumLevel = stl.LogLevel.trace
        ..addSink(bridge);

      final err = StateError('boom');
      final trace = StackTrace.current;
      stl.LogManager.instance.getLogger('Err').error(
        'failed',
        error: err,
        stackTrace: trace,
        attributes: {'key': 'value'},
      );

      expect(capture.records, hasLength(1));
      final record = capture.records.first;
      expect(record.error, err);
      expect(record.stackTrace, trace);
      expect(record.attributes, {'key': 'value'});
    });

    test('preserves spanId and traceId', () {
      final bridge = StructLogBridgeSink(target: slManager);
      stl.LogManager.instance
        ..minimumLevel = stl.LogLevel.trace
        ..addSink(bridge);

      stl.LogManager.instance.getLogger('Otel').info(
            'traced',
            spanId: 'span-123',
            traceId: 'trace-456',
          );

      final record = capture.records.first;
      expect(record.spanId, 'span-123');
      expect(record.traceId, 'trace-456');
    });

    test('prefixes loggerName with monty.', () {
      final bridge = StructLogBridgeSink(target: slManager);
      stl.LogManager.instance
        ..minimumLevel = stl.LogLevel.trace
        ..addSink(bridge);

      stl.LogManager.instance.getLogger('PluginRegistry').debug(
            'registering plugin',
          );

      expect(capture.records.first.loggerName, 'monty.PluginRegistry');
    });
  });
}

class _CaptureSink implements sl.LogSink {
  final records = <sl.LogRecord>[];

  @override
  void write(sl.LogRecord record) => records.add(record);

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}
