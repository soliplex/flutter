import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

/// Tracks dispose calls for test verification.
class _MockBridge implements MontyBridge {
  bool disposed = false;

  @override
  List<HostFunctionSchema> get schemas => [];

  @override
  void register(HostFunction function) {}

  @override
  void unregister(String name) {}

  @override
  Stream<BridgeEvent> execute(String code) => const Stream.empty();

  @override
  void dispose() => disposed = true;
}

const ThreadKey _key1 = (serverId: 's', roomId: 'r', threadId: 't1');
const ThreadKey _key2 = (serverId: 's', roomId: 'r', threadId: 't2');
const ThreadKey _key3 = (serverId: 's', roomId: 'r', threadId: 't3');

void main() {
  group('BridgeCache', () {
    late List<_MockBridge> createdBridges;
    late BridgeCache cache;

    setUp(() {
      createdBridges = [];
      cache = BridgeCache(
        limit: 2,
        bridgeFactory: () {
          final bridge = _MockBridge();
          createdBridges.add(bridge);
          return bridge;
        },
      );
    });

    tearDown(() => cache.disposeAll());

    group('acquire/release round-trip', () {
      test('creates bridge on first acquire', () {
        final bridge = cache.acquire(_key1);

        expect(bridge, isA<MontyBridge>());
        expect(cache.length, 1);
        expect(cache.contains(_key1), isTrue);
        expect(cache.isExecuting(_key1), isTrue);
      });

      test('returns same bridge on second acquire', () {
        final first = cache.acquire(_key1);
        cache.release(_key1);
        final second = cache.acquire(_key1);

        expect(identical(first, second), isTrue);
        expect(createdBridges, hasLength(1));
      });

      test('release marks bridge as not executing', () {
        cache.acquire(_key1);
        expect(cache.isExecuting(_key1), isTrue);

        cache.release(_key1);
        expect(cache.isExecuting(_key1), isFalse);
        expect(cache.contains(_key1), isTrue);
      });

      test('throws on re-acquire while executing', () {
        cache.acquire(_key1);

        expect(
          () => cache.acquire(_key1),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('already executing'),
            ),
          ),
        );
      });

      test('release is idempotent for unknown key', () {
        cache.release(_key1);
        expect(cache.length, 0);
      });
    });

    group('LRU eviction', () {
      test('evicts oldest idle bridge when at limit', () {
        cache
          ..acquire(_key1)
          ..release(_key1)
          ..acquire(_key2)
          ..release(_key2)
          // At limit (2). Acquiring key3 should evict key1 (LRU).
          ..acquire(_key3);

        expect(cache.contains(_key1), isFalse);
        expect(cache.contains(_key2), isTrue);
        expect(cache.contains(_key3), isTrue);
        expect(createdBridges[0].disposed, isTrue);
      });

      test('evicts idle bridge even if newer bridge is executing', () {
        cache
          ..acquire(_key1)
          ..release(_key1)
          ..acquire(_key2)
          // key2 is executing, key1 is idle
          // At limit. key1 is LRU and idle — should be evicted.
          ..acquire(_key3);

        expect(cache.contains(_key1), isFalse);
        expect(cache.contains(_key2), isTrue);
        expect(cache.contains(_key3), isTrue);
      });

      test('reacquire moves bridge to MRU position', () {
        cache
          ..acquire(_key1)
          ..release(_key1)
          ..acquire(_key2)
          ..release(_key2)
          // Reacquire key1 — moves it to MRU.
          ..acquire(_key1)
          ..release(_key1)
          // Now key2 is LRU. Acquiring key3 should evict key2.
          ..acquire(_key3);

        expect(cache.contains(_key1), isTrue);
        expect(cache.contains(_key2), isFalse);
        expect(cache.contains(_key3), isTrue);
      });
    });

    group('WASM guard', () {
      test('throws StateError when all bridges are executing', () {
        cache
          ..acquire(_key1)
          ..acquire(_key2);
        // Both executing, at limit.

        expect(
          () => cache.acquire(_key3),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('WASM concurrency limit'),
            ),
          ),
        );
      });

      test('does not throw after releasing one bridge', () {
        cache
          ..acquire(_key1)
          ..acquire(_key2)
          ..release(_key1);

        // key1 is idle, can be evicted.
        expect(() => cache.acquire(_key3), returnsNormally);
      });
    });

    group('evict', () {
      test('removes and disposes a specific bridge', () {
        cache
          ..acquire(_key1)
          ..release(_key1)
          ..evict(_key1);

        expect(cache.contains(_key1), isFalse);
        expect(cache.length, 0);
        expect(createdBridges[0].disposed, isTrue);
      });

      test('clears executing state', () {
        cache.acquire(_key1);
        expect(cache.isExecuting(_key1), isTrue);

        cache.evict(_key1);
        expect(cache.isExecuting(_key1), isFalse);
      });

      test('does nothing for unknown key', () {
        cache.evict(_key1);
        expect(cache.length, 0);
      });
    });

    group('disposeAll', () {
      test('disposes all cached bridges', () {
        cache
          ..acquire(_key1)
          ..acquire(_key2)
          ..disposeAll();

        expect(cache.length, 0);
        expect(createdBridges[0].disposed, isTrue);
        expect(createdBridges[1].disposed, isTrue);
      });

      test('clears executing state', () {
        cache
          ..acquire(_key1)
          ..disposeAll();

        expect(cache.isExecuting(_key1), isFalse);
      });
    });

    group('limit = 1 (WASM scenario)', () {
      late BridgeCache wasmCache;

      setUp(() {
        wasmCache = BridgeCache(
          limit: 1,
          bridgeFactory: () {
            final bridge = _MockBridge();
            createdBridges.add(bridge);
            return bridge;
          },
        );
      });

      tearDown(() => wasmCache.disposeAll());

      test('single bridge acquire/release cycle', () {
        final bridge = wasmCache.acquire(_key1);
        wasmCache.release(_key1);

        expect(bridge, isA<MontyBridge>());
        expect(wasmCache.length, 1);
      });

      test('throws on second concurrent acquire', () {
        wasmCache.acquire(_key1);

        expect(
          () => wasmCache.acquire(_key2),
          throwsStateError,
        );
      });

      test('allows sequential use after release', () {
        wasmCache
          ..acquire(_key1)
          ..release(_key1);

        // key1 is idle, can be evicted for key2.
        expect(() => wasmCache.acquire(_key2), returnsNormally);
        expect(wasmCache.contains(_key1), isFalse);
        expect(wasmCache.contains(_key2), isTrue);
      });
    });
  });
}
