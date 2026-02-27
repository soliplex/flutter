import 'dart:convert';

import 'package:dart_monty_native/dart_monty_native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/models/thread_key.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_monty/soliplex_monty.dart';

/// Per-thread [MontyBridge] state — maps each (room, thread) to its bridge.
typedef ThreadBridgeCacheState = Map<ThreadKey, MontyBridge>;

/// Manages a per-thread [MontyBridge] cache.
///
/// Each (room, thread) pair gets its own [DefaultMontyBridge] backed by a
/// dedicated [MontyNative] instance (separate Dart Isolate + Python
/// interpreter). This eliminates platform singleton contention when multiple
/// threads execute Python concurrently.
///
/// Bridges are created lazily via [getOrCreate] and disposed:
/// - All bridges on room change (new room = new tool definitions)
/// - All bridges on provider disposal
/// - Individual bridges via [removeThread]
class ThreadBridgeCacheNotifier extends Notifier<ThreadBridgeCacheState> {
  /// Local bridge references accessible during disposal.
  ///
  /// Mirrors [state] but is a plain field, not a Riverpod-managed getter.
  /// This avoids the Riverpod 3.0 restriction that forbids accessing `state`
  /// inside `ref.onDispose` callbacks.
  @visibleForTesting
  Map<ThreadKey, MontyBridge> bridges = {};

  @override
  ThreadBridgeCacheState build() {
    bridges = {};
    ref
      ..listen(currentRoomProvider, (prev, next) {
        if (prev?.id != next?.id) _disposeAll();
      })
      ..onDispose(_disposeBridges);
    return {};
  }

  /// Returns the bridge for [key], creating one if it doesn't exist.
  ///
  /// On first call for a given key, creates a new [MontyNative] with its
  /// own [NativeIsolateBindingsImpl] (separate Dart Isolate) and registers
  /// all [mappings] as host functions that dispatch through the tool registry.
  MontyBridge getOrCreate(ThreadKey key, List<ToolNameMapping> mappings) {
    final existing = bridges[key];
    if (existing != null) return existing;

    Loggers.montyBridge.info(
      'Creating bridge for thread ${key.threadId} '
      'in room ${key.roomId} '
      'with ${mappings.length} host functions',
    );

    final platform = MontyNative(bindings: NativeIsolateBindingsImpl());
    final bridge = DefaultMontyBridge(platform: platform);

    for (final mapping in mappings) {
      bridge.register(
        HostFunction(
          schema: mapping.schema,
          handler: (args) async {
            final registry = ref.read(toolRegistryProvider);
            final toolCall = ToolCallInfo(
              id: 'monty_${mapping.pythonName}_'
                  '${DateTime.now().millisecondsSinceEpoch}',
              name: mapping.registryName,
              arguments: jsonEncode(args),
            );
            Loggers.montyBridge.debug(
              'Dispatching ${mapping.pythonName} '
              '→ ${mapping.registryName}',
            );
            return registry.execute(toolCall);
          },
        ),
      );
    }

    bridges[key] = bridge;
    state = Map.of(bridges);
    return bridge;
  }

  /// Removes and disposes the bridge for [key].
  void removeThread(ThreadKey key) {
    final bridge = bridges.remove(key);
    if (bridge == null) return;

    Loggers.montyBridge.debug('Removing bridge for thread ${key.threadId}');
    bridge.dispose();
    state = Map.of(bridges);
  }

  /// Disposes all bridges and clears state.
  ///
  /// Used on room change where we need to update observable state.
  void _disposeAll() {
    _disposeBridges();
    state = {};
  }

  /// Disposes all bridges without modifying Riverpod state.
  ///
  /// Used in `ref.onDispose` where `state` access is forbidden
  /// (Riverpod lifecycle restriction). Reads from [bridges] instead.
  void _disposeBridges() {
    if (bridges.isEmpty) return;

    Loggers.montyBridge.info('Disposing all ${bridges.length} bridges');
    for (final bridge in bridges.values) {
      bridge.dispose();
    }
    bridges.clear();
  }
}

/// Per-thread [MontyBridge] cache provider.
final threadBridgeCacheProvider =
    NotifierProvider<ThreadBridgeCacheNotifier, ThreadBridgeCacheState>(
  ThreadBridgeCacheNotifier.new,
);
