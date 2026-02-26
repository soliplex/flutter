import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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

void main() {
  const key1 = (roomId: 'room-1', threadId: 'thread-1');
  const key2 = (roomId: 'room-1', threadId: 'thread-2');

  group('ThreadBridgeCacheNotifier', () {
    test('starts with empty state', () {
      final container = ProviderContainer(
        overrides: [
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
  });
}
