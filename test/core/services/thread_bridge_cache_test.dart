import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/services/thread_bridge_cache.dart';
import 'package:soliplex_monty/soliplex_monty.dart';

class MockMontyBridge extends Mock implements MontyBridge {}

/// Testable notifier that creates mock bridges instead of real MontyNative.
///
/// Avoids FFI dependency while testing cache lifecycle (lookup, removal,
/// disposal). The real [getOrCreate] with FFI is covered by integration tests.
class _TestBridgeCacheNotifier extends ThreadBridgeCacheNotifier {
  final List<MockMontyBridge> createdBridges = [];

  @override
  MontyBridge getOrCreate(
    ({String roomId, String threadId}) key,
    List<ToolNameMapping> mappings,
  ) {
    final existing = bridges[key];
    if (existing != null) return existing;

    final bridge = MockMontyBridge();
    createdBridges.add(bridge);
    bridges[key] = bridge;
    state = Map.of(bridges);
    return bridge;
  }
}

/// Mutable room notifier for triggering room changes in tests.
///
/// Replaces Riverpod 2's `StateProvider` pattern.
class _MutableRoomNotifier extends Notifier<Room?> {
  _MutableRoomNotifier(this._initial);

  final Room? _initial;

  @override
  Room? build() => _initial;

  // ignore: use_setters_to_change_properties
  void set(Room? room) => state = room;
}

void main() {
  const key1 = (roomId: 'room-1', threadId: 'thread-1');
  const key2 = (roomId: 'room-1', threadId: 'thread-2');
  const room1 = Room(id: 'room-1', name: 'Room 1');
  const room2 = Room(id: 'room-2', name: 'Room 2');

  group('ThreadBridgeCacheNotifier', () {
    test('starts with empty state', () {
      final container = ProviderContainer(
        overrides: [
          currentRoomProvider.overrideWithValue(room1),
          threadBridgeCacheProvider.overrideWith(
            _TestBridgeCacheNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(threadBridgeCacheProvider);

      expect(state, isEmpty);
    });

    test('getOrCreate returns same bridge for same key', () {
      final notifier = _TestBridgeCacheNotifier();
      final container = ProviderContainer(
        overrides: [
          currentRoomProvider.overrideWithValue(room1),
          threadBridgeCacheProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      final cacheNotifier = container.read(threadBridgeCacheProvider.notifier);
      final bridge1 = cacheNotifier.getOrCreate(key1, const []);
      final bridge2 = cacheNotifier.getOrCreate(key1, const []);

      expect(identical(bridge1, bridge2), isTrue);
      expect(notifier.createdBridges, hasLength(1));
    });

    test('getOrCreate creates different bridges for different keys', () {
      final notifier = _TestBridgeCacheNotifier();
      final container = ProviderContainer(
        overrides: [
          currentRoomProvider.overrideWithValue(room1),
          threadBridgeCacheProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      final cacheNotifier = container.read(threadBridgeCacheProvider.notifier);
      final bridge1 = cacheNotifier.getOrCreate(key1, const []);
      final bridge2 = cacheNotifier.getOrCreate(key2, const []);

      expect(identical(bridge1, bridge2), isFalse);
      expect(notifier.createdBridges, hasLength(2));
    });

    test('removeThread removes and disposes bridge', () {
      final notifier = _TestBridgeCacheNotifier();
      final container = ProviderContainer(
        overrides: [
          currentRoomProvider.overrideWithValue(room1),
          threadBridgeCacheProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      final cacheNotifier = container.read(threadBridgeCacheProvider.notifier);
      final bridge = cacheNotifier.getOrCreate(key1, const []);

      expect(container.read(threadBridgeCacheProvider), hasLength(1));

      cacheNotifier.removeThread(key1);

      expect(container.read(threadBridgeCacheProvider), isEmpty);
      verify(() => (bridge as MockMontyBridge).dispose()).called(1);
    });

    test('removeThread is no-op for unknown key', () {
      final container = ProviderContainer(
        overrides: [
          currentRoomProvider.overrideWithValue(room1),
          threadBridgeCacheProvider.overrideWith(
            _TestBridgeCacheNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      // Should not throw.
      container.read(threadBridgeCacheProvider.notifier).removeThread(key1);

      expect(container.read(threadBridgeCacheProvider), isEmpty);
    });

    test('container disposal disposes all bridges', () {
      final notifier = _TestBridgeCacheNotifier();
      final container = ProviderContainer(
        overrides: [
          currentRoomProvider.overrideWithValue(room1),
          threadBridgeCacheProvider.overrideWith(() => notifier),
        ],
      );

      container.read(threadBridgeCacheProvider.notifier)
        ..getOrCreate(key1, const [])
        ..getOrCreate(key2, const []);

      expect(notifier.createdBridges, hasLength(2));

      container.dispose();

      for (final bridge in notifier.createdBridges) {
        verify(bridge.dispose).called(1);
      }
    });

    test('room change disposes all bridges', () {
      final roomNotifier = _MutableRoomNotifier(room1);
      final mutableRoomProvider = NotifierProvider<_MutableRoomNotifier, Room?>(
        () => roomNotifier,
      );

      final notifier = _TestBridgeCacheNotifier();
      final container = ProviderContainer(
        overrides: [
          currentRoomProvider.overrideWith(
            (ref) => ref.watch(mutableRoomProvider),
          ),
          threadBridgeCacheProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      container.read(threadBridgeCacheProvider.notifier)
        ..getOrCreate(key1, const [])
        ..getOrCreate(key2, const []);

      expect(notifier.createdBridges, hasLength(2));

      // Change room — should dispose all bridges.
      // The listener fires lazily when the cache provider is next read.
      container.read(mutableRoomProvider.notifier).set(room2);
      expect(container.read(threadBridgeCacheProvider), isEmpty);

      for (final bridge in notifier.createdBridges) {
        verify(bridge.dispose).called(1);
      }
    });

    test('room change to same room does not dispose bridges', () {
      final roomNotifier = _MutableRoomNotifier(room1);
      final mutableRoomProvider = NotifierProvider<_MutableRoomNotifier, Room?>(
        () => roomNotifier,
      );

      final notifier = _TestBridgeCacheNotifier();
      final container = ProviderContainer(
        overrides: [
          currentRoomProvider.overrideWith(
            (ref) => ref.watch(mutableRoomProvider),
          ),
          threadBridgeCacheProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      container.read(threadBridgeCacheProvider.notifier).getOrCreate(
        key1,
        const [],
      );

      // Set same room again (same ID).
      container.read(mutableRoomProvider.notifier).set(
            const Room(id: 'room-1', name: 'Room 1 Updated'),
          );

      // Read triggers listener; same room ID → no disposal.
      expect(container.read(threadBridgeCacheProvider), hasLength(1));
      verifyNever(() => notifier.createdBridges.first.dispose());
    });
  });
}
