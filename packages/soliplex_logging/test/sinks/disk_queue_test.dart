import 'dart:io';

import 'package:soliplex_logging/src/sinks/disk_queue_io.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late PlatformDiskQueue queue;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('disk_queue_test_');
    queue = PlatformDiskQueue(directoryPath: tempDir.path);
  });

  tearDown(() async {
    await queue.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('DiskQueue (io)', () {
    test('append and drain round-trip', () async {
      await queue.append({'msg': 'hello', 'level': 'info'});
      await queue.append({'msg': 'world', 'level': 'debug'});

      final records = await queue.drain(10);
      expect(records, hasLength(2));
      expect(records[0]['msg'], 'hello');
      expect(records[1]['msg'], 'world');
    });

    test('appendSync writes to fatal file synchronously', () {
      queue.appendSync({'msg': 'sync-write'});

      // Verify fatal file content immediately (no await).
      final fatalFile = File('${tempDir.path}/log_queue_fatal.jsonl');
      final content = fatalFile.readAsStringSync();
      expect(content, contains('sync-write'));
    });

    test('appendSync records merge into drain results', () async {
      queue.appendSync({'msg': 'fatal-record'});
      await queue.append({'msg': 'normal-record'});

      final records = await queue.drain(10);
      expect(records, hasLength(2));
      final messages = records.map((r) => r['msg']).toList();
      expect(messages, contains('fatal-record'));
      expect(messages, contains('normal-record'));
    });

    test('confirm removes records', () async {
      await queue.append({'msg': 'first'});
      await queue.append({'msg': 'second'});
      await queue.append({'msg': 'third'});

      await queue.confirm(2);

      final records = await queue.drain(10);
      expect(records, hasLength(1));
      expect(records[0]['msg'], 'third');
    });

    test('survives simulated crash (new instance reads pending)', () async {
      await queue.append({'msg': 'before-crash'});
      await queue.close();

      final newQueue = PlatformDiskQueue(directoryPath: tempDir.path);
      final records = await newQueue.drain(10);
      expect(records, hasLength(1));
      expect(records[0]['msg'], 'before-crash');
      await newQueue.close();
    });

    test('corrupted JSONL line is skipped', () async {
      final file = File('${tempDir.path}/log_queue.jsonl');
      await file.writeAsString(
        '{"msg":"valid1"}\n'
        'this is not json\n'
        '{"msg":"valid2"}\n',
      );

      final records = await queue.drain(10);
      expect(records, hasLength(2));
      expect(records[0]['msg'], 'valid1');
      expect(records[1]['msg'], 'valid2');
    });

    test('non-Map JSON values are skipped', () async {
      final file = File('${tempDir.path}/log_queue.jsonl');
      await file.writeAsString(
        '{"msg":"valid"}\n'
        '[1,2,3]\n'
        '"just a string"\n'
        '42\n',
      );

      final records = await queue.drain(10);
      expect(records, hasLength(1));
      expect(records[0]['msg'], 'valid');
    });

    test('pendingCount is accurate', () async {
      expect(await queue.pendingCount, 0);

      await queue.append({'msg': 'a'});
      await queue.append({'msg': 'b'});
      expect(await queue.pendingCount, 2);

      await queue.confirm(1);
      expect(await queue.pendingCount, 1);
    });

    test('drain returns empty list when no records', () async {
      final records = await queue.drain(10);
      expect(records, isEmpty);
    });

    test('drain respects count limit', () async {
      for (var i = 0; i < 5; i++) {
        await queue.append({'msg': 'record-$i'});
      }

      final records = await queue.drain(3);
      expect(records, hasLength(3));
      expect(records[0]['msg'], 'record-0');
      expect(records[2]['msg'], 'record-2');
    });

    test('file rotation drops oldest when exceeding size limit', () async {
      final bigPayload = 'x' * 10000;
      for (var i = 0; i < 1200; i++) {
        await queue.append({'msg': bigPayload, 'i': i});
      }

      final count = await queue.pendingCount;
      expect(count, lessThan(1200));
      expect(count, greaterThan(0));
    });

    test('concurrent appends are serialized', () async {
      final futures = <Future<void>>[];
      for (var i = 0; i < 20; i++) {
        futures.add(queue.append({'msg': 'concurrent-$i'}));
      }
      await Future.wait(futures);

      final records = await queue.drain(20);
      expect(records, hasLength(20));
    });
  });
}
