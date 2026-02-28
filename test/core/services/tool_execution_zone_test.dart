import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/services/tool_execution_zone.dart';

void main() {
  group('tool execution zone', () {
    test('activeThreadKey returns null outside zone', () {
      expect(activeThreadKey, isNull);
    });

    test('activeThreadKey returns correct key inside zone', () async {
      const key = (roomId: 'room-1', threadId: 'thread-1');

      await runInToolExecutionZone(key, () async {
        expect(activeThreadKey, equals(key));
      });
    });

    test('nested zones use innermost key', () async {
      const outerKey = (roomId: 'room-1', threadId: 'thread-1');
      const innerKey = (roomId: 'room-2', threadId: 'thread-2');

      await runInToolExecutionZone(outerKey, () async {
        expect(activeThreadKey, equals(outerKey));

        await runInToolExecutionZone(innerKey, () async {
          expect(activeThreadKey, equals(innerKey));
        });

        // Outer key restored after inner zone exits.
        expect(activeThreadKey, equals(outerKey));
      });
    });

    test('concurrent zones are isolated', () async {
      const key1 = (roomId: 'room-1', threadId: 'thread-1');
      const key2 = (roomId: 'room-2', threadId: 'thread-2');

      final results = await Future.wait([
        runInToolExecutionZone(key1, () async {
          await Future<void>.delayed(Duration.zero);
          return activeThreadKey;
        }),
        runInToolExecutionZone(key2, () async {
          await Future<void>.delayed(Duration.zero);
          return activeThreadKey;
        }),
      ]);

      expect(results[0], equals(key1));
      expect(results[1], equals(key2));
    });

    test('key is null after zone exits', () async {
      const key = (roomId: 'room-1', threadId: 'thread-1');

      await runInToolExecutionZone(key, () async {
        expect(activeThreadKey, isNotNull);
      });

      expect(activeThreadKey, isNull);
    });

    test('returns value from body', () async {
      const key = (roomId: 'room-1', threadId: 'thread-1');

      final result = await runInToolExecutionZone(key, () async => 42);

      expect(result, equals(42));
    });
  });
}
