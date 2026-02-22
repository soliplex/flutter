import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/features/log_viewer/log_viewer_controller.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

LogRecord _makeRecord({
  LogLevel level = LogLevel.info,
  String message = 'Test message',
  String loggerName = 'Test',
  DateTime? timestamp,
}) {
  return LogRecord(
    level: level,
    message: message,
    loggerName: loggerName,
    timestamp: timestamp ?? DateTime(2024, 1, 15, 10, 30, 45, 123),
  );
}

void main() {
  group('LogViewerController.exportFilteredAsJsonlBytes', () {
    late MemorySink sink;
    late LogViewerController controller;

    setUp(() {
      sink = MemorySink();
      controller = LogViewerController(sink: sink, onChanged: () {});
    });

    tearDown(() {
      controller.dispose();
    });

    test('returns valid JSONL', () {
      sink
        ..write(_makeRecord(message: 'First'))
        ..write(_makeRecord(message: 'Second'));
      // Re-create controller to pick up records written before construction.
      controller.dispose();
      controller = LogViewerController(sink: sink, onChanged: () {});

      final bytes = controller.exportFilteredAsJsonlBytes();
      final lines = utf8.decode(bytes).trimRight().split('\n');

      expect(lines, hasLength(2));
      for (final line in lines) {
        final map = jsonDecode(line) as Map<String, Object?>;
        expect(map, containsPair('level', 'info'));
        expect(map, containsPair('logger', 'Test'));
      }
      expect(
        (jsonDecode(lines[0]) as Map)['message'],
        'First',
      );
      expect(
        (jsonDecode(lines[1]) as Map)['message'],
        'Second',
      );
    });

    test('respects level filter', () {
      sink
        ..write(_makeRecord(message: 'Info'))
        ..write(_makeRecord(level: LogLevel.error, message: 'Error'));
      controller.dispose();
      controller = LogViewerController(sink: sink, onChanged: () {})
        ..setSelectedLevels({LogLevel.error});

      final bytes = controller.exportFilteredAsJsonlBytes();
      final lines = utf8.decode(bytes).trimRight().split('\n');

      expect(lines, hasLength(1));
      expect(
        (jsonDecode(lines[0]) as Map)['message'],
        'Error',
      );
    });

    test('respects logger exclusion', () {
      sink
        ..write(_makeRecord(loggerName: 'Auth', message: 'Auth msg'))
        ..write(_makeRecord(loggerName: 'Chat', message: 'Chat msg'));
      controller.dispose();
      controller = LogViewerController(sink: sink, onChanged: () {})
        ..setExcludedLoggers({'Auth'});

      final bytes = controller.exportFilteredAsJsonlBytes();
      final lines = utf8.decode(bytes).trimRight().split('\n');

      expect(lines, hasLength(1));
      expect(
        (jsonDecode(lines[0]) as Map)['message'],
        'Chat msg',
      );
    });

    test('respects search query', () {
      sink
        ..write(_makeRecord(message: 'User logged in'))
        ..write(_makeRecord(message: 'HTTP request'));
      controller.dispose();
      controller = LogViewerController(sink: sink, onChanged: () {})
        ..setSearchQuery('logged');

      final bytes = controller.exportFilteredAsJsonlBytes();
      final lines = utf8.decode(bytes).trimRight().split('\n');

      expect(lines, hasLength(1));
      expect(
        (jsonDecode(lines[0]) as Map)['message'],
        'User logged in',
      );
    });

    test('empty filtered list returns empty bytes', () {
      // No records written — controller has nothing.
      final bytes = controller.exportFilteredAsJsonlBytes();
      expect(bytes.length, 0);
    });

    test('flushes pending records before export', () async {
      // Write a record after controller construction — it goes into the
      // pending buffer and hasn't been flushed yet.
      sink.write(_makeRecord(message: 'Pending'));

      // Don't wait for the flush timer — export should flush internally.
      final bytes = controller.exportFilteredAsJsonlBytes();
      final lines = utf8.decode(bytes).trimRight().split('\n');

      expect(lines, hasLength(1));
      expect(
        (jsonDecode(lines[0]) as Map)['message'],
        'Pending',
      );
    });

    test('chronological order preserved', () {
      sink
        ..write(
          _makeRecord(
            message: 'Old',
            timestamp: DateTime(2024, 1, 15, 10),
          ),
        )
        ..write(
          _makeRecord(
            message: 'New',
            timestamp: DateTime(2024, 1, 15, 11),
          ),
        );
      controller.dispose();
      controller = LogViewerController(sink: sink, onChanged: () {});

      final bytes = controller.exportFilteredAsJsonlBytes();
      final lines = utf8.decode(bytes).trimRight().split('\n');

      expect(lines, hasLength(2));
      expect(
        (jsonDecode(lines[0]) as Map)['message'],
        'Old',
      );
      expect(
        (jsonDecode(lines[1]) as Map)['message'],
        'New',
      );
    });
  });
}
