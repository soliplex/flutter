import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart'
    show MontyLimits;
import 'package:soliplex_agent/soliplex_agent.dart' show ThreadKey;
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

/// Manages a pool of [MontyBridge] instances keyed by [ThreadKey].
///
/// Bridges are lazily created on first [acquire] and cached for reuse by
/// the same thread. When the concurrency limit is reached, the
/// least-recently-used idle bridge is evicted and disposed.
///
/// The WASM guard throws [StateError] when all bridges are executing
/// and the limit is reached — preventing deadlock on single-threaded
/// platforms.
///
/// **Deprecated.** Use `MontyScriptEnvironment` instead. Will be removed
/// in V8.
class BridgeCache {
  /// Creates a cache with the given concurrency [limit] and optional
  /// [bridgeFactory] for creating new bridges.
  ///
  /// When no [bridgeFactory] is provided, bridges are created as
  /// `DefaultMontyBridge(useFutures: false, limits: defaultLimits)`.
  BridgeCache({
    required int limit,
    MontyBridge Function()? bridgeFactory,
    MontyLimits? defaultLimits,
  })  : _limit = limit,
        _factory = bridgeFactory,
        _defaultLimits = defaultLimits;

  final int _limit;
  final MontyBridge Function()? _factory;
  final MontyLimits? _defaultLimits;

  /// Bridges keyed by thread. Insertion order tracks LRU (oldest first).
  final _bridges = <ThreadKey, MontyBridge>{};

  /// Threads whose bridge is currently executing.
  final _executing = <ThreadKey>{};

  /// Number of cached bridges.
  int get length => _bridges.length;

  /// Whether a bridge exists for [key].
  bool contains(ThreadKey key) => _bridges.containsKey(key);

  /// Whether the bridge for [key] is currently executing.
  bool isExecuting(ThreadKey key) => _executing.contains(key);

  /// Returns the bridge for [key], creating one if needed.
  ///
  /// If the cache is at capacity, the least-recently-used idle bridge
  /// is evicted. Throws [StateError] if all bridges are executing
  /// (WASM guard).
  MontyBridge acquire(ThreadKey key) {
    if (_executing.contains(key)) {
      throw StateError(
        'Bridge for $key is already executing. '
        'Concurrent execution on the same bridge is not allowed.',
      );
    }

    final existing = _bridges.remove(key);
    if (existing != null) {
      // Move to end (most-recently-used).
      _bridges[key] = existing;
      _executing.add(key);
      return existing;
    }

    // At capacity — evict LRU idle bridge.
    if (_bridges.length >= _limit) {
      _evictLru();
    }

    final bridge = _factory?.call() ??
        DefaultMontyBridge(useFutures: false, limits: _defaultLimits);
    _bridges[key] = bridge;
    _executing.add(key);
    return bridge;
  }

  /// Marks the bridge for [key] as no longer executing.
  ///
  /// The bridge remains cached for reuse. Does nothing if [key] is
  /// not in the cache.
  void release(ThreadKey key) {
    _executing.remove(key);
  }

  /// Removes and disposes the bridge for [key].
  void evict(ThreadKey key) {
    _executing.remove(key);
    _bridges.remove(key)?.dispose();
  }

  /// Disposes all cached bridges, then clears the cache.
  void disposeAll() {
    for (final bridge in _bridges.values) {
      bridge.dispose();
    }
    _bridges.clear();
    _executing.clear();
  }

  /// Evicts the least-recently-used idle bridge.
  ///
  /// Throws [StateError] if all bridges are executing.
  void _evictLru() {
    for (final key in _bridges.keys) {
      if (!_executing.contains(key)) {
        evict(key);
        return;
      }
    }
    throw StateError(
      'All $_limit bridges are executing. '
      'Cannot allocate another bridge (WASM concurrency limit).',
    );
  }
}
