import 'dart:developer' as developer;

import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_monty/soliplex_monty.dart';

/// Validates a [Room]'s tool definitions through [SchemaExecutor].
///
/// Takes a Room (already parsed by `roomFromJson`) and validates each
/// tool definition against the loaded Monty schema. Invalid tools are
/// logged and skipped; the Room is returned with only validated tools.
class NegotiatedRoomMapper {
  const NegotiatedRoomMapper(this._schemaExecutor);

  final SchemaExecutor _schemaExecutor;

  /// Validates tool definitions in [room] via [SchemaExecutor].
  ///
  /// If no 'tool' schema is loaded, returns the room unchanged.
  /// Per-tool validation failures are logged and the tool is skipped.
  Future<Room> mapRoom(Room room) async {
    if (!_schemaExecutor.hasSchemas ||
        !_schemaExecutor.schemaNames.contains('tool')) {
      return room;
    }

    if (room.toolDefinitions.isEmpty) return room;

    final validatedTools = <Map<String, dynamic>>[];
    for (final toolDef in room.toolDefinitions) {
      try {
        final validated = await _schemaExecutor.validate('tool', toolDef);
        validatedTools.add(Map<String, dynamic>.from(validated));
      } catch (e) {
        developer.log(
          'Tool validation failed, skipping: $e '
          '(tool: ${toolDef['tool_name'] ?? toolDef['name'] ?? 'unknown'})',
          name: 'soliplex.negotiated_room_mapper',
          level: 900, // Warning level
        );
      }
    }

    return room.copyWith(toolDefinitions: validatedTools);
  }

  /// Validates tool definitions for all [rooms].
  Future<List<Room>> mapRooms(List<Room> rooms) async {
    return Future.wait(rooms.map(mapRoom));
  }
}
