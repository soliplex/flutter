@Tags(['singleton'])
library;

import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:test/test.dart';

/// A test sink that tracks calls.
class TestSink implements LogSink {
  final List<LogRecord> records = [];
  int flushCount = 0;
  bool closed = false;

  @override
  void write(LogRecord record) {
    records.add(record);
  }

  @override
  Future<void> flush() async {
    flushCount++;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  setUp(LogManager.instance.reset);

  tearDown(LogManager.instance.reset);

  group('LogManager', () {
    test('is a singleton', () {
      expect(LogManager.instance, same(LogManager.instance));
    });

    test('starts with info minimum level', () {
      expect(LogManager.instance.minimumLevel, LogLevel.info);
    });

    test('can change minimum level', () {
      LogManager.instance.minimumLevel = LogLevel.debug;
      expect(LogManager.instance.minimumLevel, LogLevel.debug);
    });

    test('starts with no sinks', () {
      expect(LogManager.instance.sinks, isEmpty);
    });

    test('can add a sink', () {
      final sink = TestSink();
      LogManager.instance.addSink(sink);

      expect(LogManager.instance.sinks, contains(sink));
    });

    test('prevents duplicate sinks', () {
      final sink = TestSink();
      LogManager.instance.addSink(sink);
      LogManager.instance.addSink(sink);

      expect(LogManager.instance.sinks, hasLength(1));
    });

    test('can remove a sink', () {
      final sink = TestSink();
      LogManager.instance.addSink(sink);
      LogManager.instance.removeSink(sink);

      expect(LogManager.instance.sinks, isEmpty);
    });

    test('emit writes to all sinks', () {
      final sink1 = TestSink();
      final sink2 = TestSink();
      LogManager.instance
        ..addSink(sink1)
        ..addSink(sink2);

      final record = LogRecord(
        level: LogLevel.info,
        message: 'Test',
        timestamp: DateTime.now(),
        loggerName: 'Test',
      );
      LogManager.instance.emit(record);

      expect(sink1.records, hasLength(1));
      expect(sink2.records, hasLength(1));
    });

    test('flush flushes all sinks', () async {
      final sink1 = TestSink();
      final sink2 = TestSink();
      LogManager.instance
        ..addSink(sink1)
        ..addSink(sink2);

      await LogManager.instance.flush();

      expect(sink1.flushCount, 1);
      expect(sink2.flushCount, 1);
    });

    test('close closes all sinks and clears list', () async {
      final sink1 = TestSink();
      final sink2 = TestSink();
      LogManager.instance
        ..addSink(sink1)
        ..addSink(sink2);

      await LogManager.instance.close();

      expect(sink1.closed, isTrue);
      expect(sink2.closed, isTrue);
      expect(LogManager.instance.sinks, isEmpty);
    });

    test('reset clears sinks and restores default level', () {
      final sink = TestSink();
      LogManager.instance
        ..addSink(sink)
        ..minimumLevel = LogLevel.trace;

      LogManager.instance.reset();

      expect(LogManager.instance.sinks, isEmpty);
      expect(LogManager.instance.minimumLevel, LogLevel.info);
    });

    test('getLogger returns a Logger with correct name', () {
      final logger = LogManager.instance.getLogger('MyLogger');

      expect(logger.name, 'MyLogger');
    });

    test('sinks list is unmodifiable', () {
      expect(
        () => LogManager.instance.sinks.add(TestSink()),
        throwsUnsupportedError,
      );
    });
  });
}
