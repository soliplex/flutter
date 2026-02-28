import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_monty/soliplex_monty.dart';

/// SchemaExecutor singleton (empty until initialized).
///
/// Holds cached Python schema validators fetched from the backend.
/// Used by NegotiatedRoomMapper to validate room tool definitions.
final schemaExecutorProvider = Provider<SchemaExecutor>((ref) {
  return SchemaExecutor();
});

/// Fetches and loads Monty schemas from the backend.
///
/// Non-fatal on failure — logs a warning and falls back to static mappers.
/// Watches [apiProvider] and [schemaExecutorProvider].
final schemaInitProvider = FutureProvider<void>((ref) async {
  final api = ref.watch(apiProvider);
  final executor = ref.read(schemaExecutorProvider);
  try {
    final schemas = await api.getMontySchemas();
    if (schemas.isNotEmpty) {
      executor.loadSchemas(schemas);
      Loggers.room.info('Loaded ${schemas.length} Monty schema(s)');
    }
  } catch (e, st) {
    Loggers.room.warning(
      'Failed to load Monty schemas, falling back to static mappers',
      error: e,
      stackTrace: st,
    );
  }
});
