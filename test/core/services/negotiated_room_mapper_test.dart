import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:dart_monty_platform_interface/dart_monty_testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/services/negotiated_room_mapper.dart';
import 'package:soliplex_monty/soliplex_monty.dart';

const _usage = MontyResourceUsage(
  memoryBytesUsed: 1024,
  timeElapsedMs: 10,
  stackDepthUsed: 5,
);

void main() {
  late MockMontyPlatform mockPlatform;
  late SchemaExecutor executor;
  late NegotiatedRoomMapper mapper;

  setUp(() {
    mockPlatform = MockMontyPlatform();
    executor = SchemaExecutor(platform: mockPlatform);
    mapper = NegotiatedRoomMapper(executor);
  });

  group('NegotiatedRoomMapper', () {
    test('returns room unchanged when no schemas loaded', () async {
      const room = Room(
        id: 'room-1',
        name: 'Test',
        toolDefinitions: [
          {'tool_name': 'search'},
        ],
      );

      final result = await mapper.mapRoom(room);

      expect(result.toolDefinitions, equals(room.toolDefinitions));
    });

    test('returns room unchanged when no tool schema loaded', () async {
      executor.loadSchemas({
        'other': 'def validate_other(raw):\n    return raw\n',
      });

      const room = Room(
        id: 'room-1',
        name: 'Test',
        toolDefinitions: [
          {'tool_name': 'search'},
        ],
      );

      final result = await mapper.mapRoom(room);

      expect(result.toolDefinitions, equals(room.toolDefinitions));
    });

    test('returns room unchanged when no tool definitions', () async {
      executor.loadSchemas({
        'tool': 'def validate_tool(raw):\n    return raw\n',
      });

      const room = Room(id: 'room-1', name: 'Test');

      final result = await mapper.mapRoom(room);

      expect(result.toolDefinitions, isEmpty);
    });

    test('validates tools through SchemaExecutor', () async {
      executor.loadSchemas({
        'tool': 'def validate_tool(raw):\n    return raw\n',
      });

      mockPlatform.runResult = const MontyResult(
        value: {'tool_name': 'search', 'validated': true},
        usage: _usage,
      );

      const room = Room(
        id: 'room-1',
        name: 'Test',
        toolDefinitions: [
          {'tool_name': 'search'},
        ],
      );

      final result = await mapper.mapRoom(room);

      expect(result.toolDefinitions, hasLength(1));
      expect(result.toolDefinitions[0]['tool_name'], equals('search'));
      expect(result.toolDefinitions[0]['validated'], isTrue);
    });

    test('skips tools when validation returns error', () async {
      executor.loadSchemas({
        'tool': 'def validate_tool(raw):\n    return raw\n',
      });

      mockPlatform.runResult = const MontyResult(
        error: MontyException(message: 'Validation failed'),
        usage: _usage,
      );

      const room = Room(
        id: 'room-1',
        name: 'Test',
        toolDefinitions: [
          {'tool_name': 'bad_tool'},
        ],
      );

      final result = await mapper.mapRoom(room);

      expect(result.toolDefinitions, isEmpty);
    });

    test('preserves base room fields after validation', () async {
      executor.loadSchemas({
        'tool': 'def validate_tool(raw):\n    return raw\n',
      });

      mockPlatform.runResult = const MontyResult(
        value: {'tool_name': 'search'},
        usage: _usage,
      );

      const room = Room(
        id: 'room-1',
        name: 'Test Room',
        description: 'A room',
        welcomeMessage: 'Welcome!',
        enableAttachments: true,
        toolDefinitions: [
          {'tool_name': 'search'},
        ],
        aguiFeatureNames: ['streaming'],
      );

      final result = await mapper.mapRoom(room);

      expect(result.id, equals('room-1'));
      expect(result.name, equals('Test Room'));
      expect(result.description, equals('A room'));
      expect(result.welcomeMessage, equals('Welcome!'));
      expect(result.enableAttachments, isTrue);
      expect(result.aguiFeatureNames, equals(['streaming']));
    });

    test('mapRooms validates all rooms', () async {
      executor.loadSchemas({
        'tool': 'def validate_tool(raw):\n    return raw\n',
      });

      mockPlatform.runResult = const MontyResult(
        value: {'tool_name': 'search', 'validated': true},
        usage: _usage,
      );

      const rooms = [
        Room(
          id: 'room-1',
          name: 'Room 1',
          toolDefinitions: [
            {'tool_name': 'search'},
          ],
        ),
        Room(id: 'room-2', name: 'Room 2'),
      ];

      final results = await mapper.mapRooms(rooms);

      expect(results, hasLength(2));
      expect(results[0].toolDefinitions, hasLength(1));
      expect(results[1].toolDefinitions, isEmpty);
    });
  });
}
