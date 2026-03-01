import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:test/test.dart';

void main() {
  group('ThreadKey', () {
    test('equal keys have same hashCode', () {
      const a = (serverId: 'srv-1', roomId: 'room-a', threadId: 'thread-1');
      const b = (serverId: 'srv-1', roomId: 'room-a', threadId: 'thread-1');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different serverId produces inequality', () {
      const a = (serverId: 'srv-1', roomId: 'room-a', threadId: 'thread-1');
      const b = (serverId: 'srv-2', roomId: 'room-a', threadId: 'thread-1');

      expect(a, isNot(equals(b)));
    });

    test('different roomId produces inequality', () {
      const a = (serverId: 'srv-1', roomId: 'room-a', threadId: 'thread-1');
      const b = (serverId: 'srv-1', roomId: 'room-b', threadId: 'thread-1');

      expect(a, isNot(equals(b)));
    });

    test('different threadId produces inequality', () {
      const a = (serverId: 'srv-1', roomId: 'room-a', threadId: 'thread-1');
      const b = (serverId: 'srv-1', roomId: 'room-a', threadId: 'thread-2');

      expect(a, isNot(equals(b)));
    });

    test('works as map key', () {
      const key = (serverId: 'srv-1', roomId: 'room-a', threadId: 'thread-1');
      final map = <ThreadKey, String>{key: 'value'};

      const lookup = (
        serverId: 'srv-1',
        roomId: 'room-a',
        threadId: 'thread-1',
      );

      expect(map[lookup], equals('value'));
    });
  });
}
