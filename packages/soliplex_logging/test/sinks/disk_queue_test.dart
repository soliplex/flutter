import 'dart:async';
import 'dart:convert';
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

    test('queue recovers after I/O error', () async {
      await queue.append({'msg': 'before-error'});

      // Delete directory to cause next append to fail.
      tempDir.deleteSync(recursive: true);
      try {
        await queue.append({'msg': 'will-fail'});
      } on Object {
        // Expected.
      }

      // Recreate directory — queue should still work.
      tempDir.createSync(recursive: true);
      await queue.append({'msg': 'after-error'});

      final records = await queue.drain(10);
      expect(records, hasLength(1));
      expect(records[0]['msg'], 'after-error');
    });

    test('confirm skips corrupted lines at head', () async {
      final file = File('${tempDir.path}/log_queue.jsonl');
      await file.writeAsString(
        'this is not json\n'
        '{"msg":"first"}\n'
        '{"msg":"second"}\n',
      );

      // Confirm 1 record — should skip the corrupted line
      // and remove "first", leaving only "second".
      await queue.confirm(1);

      final records = await queue.drain(10);
      expect(records, hasLength(1));
      expect(records[0]['msg'], 'second');
    });

    test('pendingCount includes fatal records', () async {
      queue.appendSync({'msg': 'fatal'});
      expect(await queue.pendingCount, 1);

      await queue.append({'msg': 'normal'});
      expect(await queue.pendingCount, 2);
    });

    test('pendingCount ignores corrupted and non-Map lines', () async {
      final file = File('${tempDir.path}/log_queue.jsonl');
      await file.writeAsString(
        '{"msg":"valid1"}\n'
        'not json at all\n'
        '[1,2,3]\n'
        '"just a string"\n'
        '{"msg":"valid2"}\n',
      );

      expect(await queue.pendingCount, 2);

      // Verify consistency: pendingCount matches drain length.
      final records = await queue.drain(10);
      expect(records, hasLength(2));
    });

    test('fatal records merge via direct append — no duplicates', () async {
      await queue.append({'msg': 'existing'});
      await queue.close();

      // Write a fatal record directly.
      File('${tempDir.path}/log_queue_fatal.jsonl')
          .writeAsStringSync('${jsonEncode({'msg': 'fatal'})}\n');

      final newQueue = PlatformDiskQueue(directoryPath: tempDir.path);
      final records = await newQueue.drain(10);
      expect(records, hasLength(2));
      final messages = records.map((r) => r['msg']).toSet();
      expect(messages, containsAll(['existing', 'fatal']));

      // Drain again to verify no duplicates.
      await newQueue.confirm(2);
      final after = await newQueue.drain(10);
      expect(after, isEmpty);
      await newQueue.close();
    });

    test('close() awaits pending writes', () async {
      // Fire-and-forget append, then immediately close.
      unawaited(queue.append({'msg': 'pending-write'}));
      await queue.close();

      // New instance should see the record.
      final newQueue = PlatformDiskQueue(directoryPath: tempDir.path);
      final records = await newQueue.drain(10);
      expect(records, hasLength(1));
      expect(records[0]['msg'], 'pending-write');
      await newQueue.close();
    });
  });

  group('Offset-based architecture', () {
    test('meta persistence across instances', () async {
      await queue.append({'msg': 'a'});
      await queue.append({'msg': 'b'});
      await queue.append({'msg': 'c'});
      await queue.confirm(2);
      await queue.close();

      final newQueue = PlatformDiskQueue(directoryPath: tempDir.path);
      expect(await newQueue.pendingCount, 1);
      final records = await newQueue.drain(10);
      expect(records, hasLength(1));
      expect(records[0]['msg'], 'c');
      await newQueue.close();
    });

    test('corrupt meta recovery — all records re-drain', () async {
      await queue.append({'msg': 'a'});
      await queue.append({'msg': 'b'});
      await queue.confirm(1);
      await queue.close();

      // Write garbage to meta file.
      File('${tempDir.path}/.queue_meta')
          .writeAsStringSync('not valid json!!!');

      final newQueue = PlatformDiskQueue(directoryPath: tempDir.path);
      // Corrupt meta → confirmed=0, all records re-drain.
      expect(await newQueue.pendingCount, 2);
      final records = await newQueue.drain(10);
      expect(records, hasLength(2));
      expect(records[0]['msg'], 'a');
      expect(records[1]['msg'], 'b');
      await newQueue.close();
    });

    test('missing meta on restart — records drain correctly', () async {
      await queue.append({'msg': 'a'});
      await queue.append({'msg': 'b'});
      await queue.confirm(1);
      await queue.close();

      // Delete meta file.
      File('${tempDir.path}/.queue_meta').deleteSync();

      final newQueue = PlatformDiskQueue(directoryPath: tempDir.path);
      // Missing meta → confirmed=0, all records available.
      expect(await newQueue.pendingCount, 2);
      await newQueue.close();
    });

    test('compaction at threshold — file shrinks', () async {
      // Use a custom queue to avoid the 500 threshold taking too long.
      // Instead, confirm enough records then trigger via append.
      // We'll write directly to the file and meta to simulate state.
      await queue.close();

      final file = File('${tempDir.path}/log_queue.jsonl');
      final sink = file.openWrite();
      for (var i = 0; i < 510; i++) {
        sink.writeln(jsonEncode({'msg': 'record-$i'}));
      }
      await sink.close();

      // Set confirmed=505 in meta.
      File('${tempDir.path}/.queue_meta')
          .writeAsStringSync(jsonEncode({'confirmed': 505}));

      final compactQueue = PlatformDiskQueue(directoryPath: tempDir.path);
      // Append triggers compaction since confirmed >= 500.
      await compactQueue.append({'msg': 'trigger'});

      // After compaction: 510 - 505 = 5 surviving + 1 new = 6.
      final records = await compactQueue.drain(20);
      expect(records, hasLength(6));
      expect(records[0]['msg'], 'record-505');
      expect(records[4]['msg'], 'record-509');
      expect(records[5]['msg'], 'trigger');
      await compactQueue.close();
    });

    test('partial confirm (BackendLogSink pattern)', () async {
      for (var i = 0; i < 10; i++) {
        await queue.append({'msg': 'r-$i'});
      }

      // Drain 10, confirm only 3 — 7 remain.
      final batch1 = await queue.drain(10);
      expect(batch1, hasLength(10));
      await queue.confirm(3);

      final batch2 = await queue.drain(10);
      expect(batch2, hasLength(7));
      expect(batch2[0]['msg'], 'r-3');
      expect(batch2[6]['msg'], 'r-9');
    });

    test('confirm(1) skip pattern', () async {
      for (var i = 0; i < 5; i++) {
        await queue.append({'msg': 'r-$i'});
      }

      await queue.drain(5);
      await queue.confirm(1);

      final records = await queue.drain(5);
      expect(records, hasLength(4));
      expect(records[0]['msg'], 'r-1');
      expect(records[3]['msg'], 'r-4');
    });

    test('fatal merge is direct append — no temp files', () async {
      await queue.append({'msg': 'existing'});
      queue.appendSync({'msg': 'fatal'});

      await queue.drain(10);

      // Verify no temp files exist.
      final files = tempDir.listSync().map((e) => e.path).toList();
      expect(files, isNot(contains(endsWith('.log_queue_merge.tmp'))));
      expect(files, isNot(contains(endsWith('.fatal_merge.jsonl'))));

      // Fatal file should be deleted after merge.
      expect(File('${tempDir.path}/log_queue_fatal.jsonl').existsSync(), false);
    });

    test('old temp file cleanup on construction', () async {
      await queue.close();

      // Create old temp files.
      for (final name in [
        '.log_queue_merge.tmp',
        '.log_queue_confirm.tmp',
        '.log_queue_rotate.tmp',
        '.fatal_merge.jsonl',
      ]) {
        File('${tempDir.path}/$name').writeAsStringSync('old data');
      }

      // Opening a new queue should clean them up.
      final newQueue = PlatformDiskQueue(directoryPath: tempDir.path);
      for (final name in [
        '.log_queue_merge.tmp',
        '.log_queue_confirm.tmp',
        '.log_queue_rotate.tmp',
        '.fatal_merge.jsonl',
      ]) {
        expect(
          File('${tempDir.path}/$name').existsSync(),
          false,
          reason: '$name should be deleted',
        );
      }
      await newQueue.close();
    });

    test('confirm does not rewrite main file', () async {
      await queue.append({'msg': 'a'});
      await queue.append({'msg': 'b'});

      final file = File('${tempDir.path}/log_queue.jsonl');
      final modBefore = file.lastModifiedSync();

      // Small delay to ensure filesystem timestamp granularity.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await queue.confirm(1);

      final modAfter = file.lastModifiedSync();
      expect(
        modAfter,
        equals(modBefore),
        reason: 'confirm should not modify the main file',
      );
    });
  });
}
