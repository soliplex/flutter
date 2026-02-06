import 'dart:async';

import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:test/test.dart';

LogRecord _record(String message) => LogRecord(
      level: LogLevel.info,
      message: message,
      timestamp: DateTime.now(),
      loggerName: 'Test',
    );

void main() {
  group('MemorySink', () {
    late MemorySink sink;

    setUp(() {
      sink = MemorySink(maxRecords: 5);
    });

    tearDown(() async {
      await sink.close();
    });

    test('starts empty', () {
      expect(sink.records, isEmpty);
      expect(sink.length, 0);
    });

    test('stores records in order', () {
      sink
        ..write(_record('first'))
        ..write(_record('second'))
        ..write(_record('third'));

      expect(sink.length, 3);
      expect(sink.records.map((r) => r.message), ['first', 'second', 'third']);
    });

    test('evicts oldest record when at capacity', () {
      for (var i = 0; i < 7; i++) {
        sink.write(_record('msg-$i'));
      }

      expect(sink.length, 5);
      expect(
        sink.records.map((r) => r.message),
        ['msg-2', 'msg-3', 'msg-4', 'msg-5', 'msg-6'],
      );
    });

    test('evicts correctly at exact boundary', () {
      for (var i = 0; i < 5; i++) {
        sink.write(_record('msg-$i'));
      }
      expect(sink.length, 5);

      sink.write(_record('msg-5'));
      expect(sink.length, 5);
      expect(sink.records.first.message, 'msg-1');
      expect(sink.records.last.message, 'msg-5');
    });

    test('records returns unmodifiable list', () {
      sink.write(_record('test'));
      expect(
        () => sink.records.add(_record('hack')),
        throwsUnsupportedError,
      );
    });

    test('clear removes all records', () {
      sink
        ..write(_record('a'))
        ..write(_record('b'));
      expect(sink.length, 2);

      sink.clear();
      expect(sink.length, 0);
      expect(sink.records, isEmpty);
    });

    test('accepts records after clear', () {
      sink
        ..write(_record('before'))
        ..clear()
        ..write(_record('after'));

      expect(sink.length, 1);
      expect(sink.records.first.message, 'after');
    });

    test('stream emits on write', () async {
      final completer = Completer<LogRecord>();
      unawaited(sink.onRecord.first.then(completer.complete));

      sink.write(_record('streamed'));

      final record = await completer.future;
      expect(record.message, 'streamed');
    });

    test('stream emits multiple records', () async {
      final messages = <String>[];
      final sub = sink.onRecord.listen((r) => messages.add(r.message));

      sink
        ..write(_record('one'))
        ..write(_record('two'))
        ..write(_record('three'));

      // Allow microtasks to complete.
      await Future<void>.delayed(Duration.zero);

      expect(messages, ['one', 'two', 'three']);
      await sub.cancel();
    });

    test('close closes the stream', () async {
      await sink.close();
      expect(sink.onRecord.isBroadcast, isTrue);
    });

    test('write does not throw after close', () async {
      await sink.close();
      // Should silently add to records without emitting to stream.
      sink.write(_record('after-close'));
      expect(sink.length, 1);
    });

    test('flush is a no-op', () async {
      await expectLater(sink.flush(), completes);
    });

    test('default maxRecords is 2000', () {
      final defaultSink = MemorySink();
      expect(defaultSink.maxRecords, 2000);
    });

    test('single record buffer works correctly', () {
      final tinySink = MemorySink(maxRecords: 1)
        ..write(_record('first'))
        ..write(_record('second'));

      expect(tinySink.length, 1);
      expect(tinySink.records.first.message, 'second');
    });
  });
}
