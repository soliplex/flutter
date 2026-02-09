// Tests for the web (in-memory) DiskQueue implementation.
//
// By importing disk_queue_web.dart directly and running on the VM, this test
// proves the web code path compiles and operates without dart:io.
import 'package:soliplex_logging/src/sinks/disk_queue_web.dart';
import 'package:test/test.dart';

void main() {
  late PlatformDiskQueue queue;

  setUp(() {
    queue = PlatformDiskQueue(directoryPath: '');
  });

  tearDown(() async {
    await queue.close();
  });

  group('DiskQueue (web / in-memory)', () {
    test('append and drain round-trip', () async {
      await queue.append({'msg': 'hello', 'level': 'info'});
      await queue.append({'msg': 'world', 'level': 'debug'});

      final records = await queue.drain(10);
      expect(records, hasLength(2));
      expect(records[0]['msg'], 'hello');
      expect(records[1]['msg'], 'world');
    });

    test('appendSync adds to queue', () async {
      queue.appendSync({'msg': 'sync-write'});

      final records = await queue.drain(10);
      expect(records, hasLength(1));
      expect(records[0]['msg'], 'sync-write');
    });

    test('confirm removes records from head', () async {
      await queue.append({'msg': 'first'});
      await queue.append({'msg': 'second'});
      await queue.append({'msg': 'third'});

      await queue.confirm(2);

      final records = await queue.drain(10);
      expect(records, hasLength(1));
      expect(records[0]['msg'], 'third');
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

    test('drain returns empty list when no records', () async {
      final records = await queue.drain(10);
      expect(records, isEmpty);
    });

    test('pendingCount is accurate', () async {
      expect(await queue.pendingCount, 0);

      await queue.append({'msg': 'a'});
      await queue.append({'msg': 'b'});
      expect(await queue.pendingCount, 2);

      await queue.confirm(1);
      expect(await queue.pendingCount, 1);
    });

    test('close clears the queue', () async {
      await queue.append({'msg': 'a'});
      await queue.append({'msg': 'b'});
      expect(await queue.pendingCount, 2);

      await queue.close();

      // After close, a new instance starts empty.
      queue = PlatformDiskQueue(directoryPath: '');
      expect(await queue.pendingCount, 0);
    });

    test('directoryPath is stored but ignored', () async {
      final custom = PlatformDiskQueue(directoryPath: '/any/path/ignored');
      await custom.append({'msg': 'works'});

      final records = await custom.drain(10);
      expect(records, hasLength(1));
      expect(records[0]['msg'], 'works');
      expect(custom.directoryPath, '/any/path/ignored');

      await custom.close();
    });

    test('append copies input map to prevent external mutation', () async {
      final input = <String, Object?>{'msg': 'original'};
      await queue.append(input);
      input['msg'] = 'mutated';

      final records = await queue.drain(10);
      expect(records[0]['msg'], 'original');
    });

    test('appendSync copies input map to prevent external mutation', () async {
      final input = <String, Object?>{'msg': 'original'};
      queue.appendSync(input);
      input['msg'] = 'mutated';

      final records = await queue.drain(10);
      expect(records[0]['msg'], 'original');
    });

    test('confirm more than available does not throw', () async {
      await queue.append({'msg': 'only-one'});

      // Confirm more records than exist — should not throw.
      await queue.confirm(5);
      expect(await queue.pendingCount, 0);
    });

    test('mixed appendSync and append interleave correctly', () async {
      queue.appendSync({'msg': 'sync-1'});
      await queue.append({'msg': 'async-1'});
      queue.appendSync({'msg': 'sync-2'});

      final records = await queue.drain(10);
      expect(records, hasLength(3));
      final messages = records.map((r) => r['msg']).toList();
      expect(messages, ['sync-1', 'async-1', 'sync-2']);
    });
  });
}
