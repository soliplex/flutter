import 'dart:async';

import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:dart_monty_wasm/dart_monty_wasm.dart';

/// Shared mutex that serializes all MontyWasm execution on web.
///
/// All `MontyWasm` instances share the `window.DartMontyBridge` JS singleton.
/// Dart on web is single-threaded, but interleaved async calls can corrupt
/// state. This mutex ensures only one platform operation runs at a time.
final _mutex = _WebMutex();

/// Creates a web `MontyPlatform` backed by WASM.
///
/// Returns a mutex-guarded wrapper around `MontyWasm`. The wrapper serializes
/// `start()`, `resume()`, and `resumeWithError()` through a shared mutex
/// so that concurrent bridges cannot corrupt the JS singleton state.
MontyPlatform createMontyPlatform() =>
    _MutexGuardedPlatform(MontyWasm(bindings: WasmBindingsJs()));

/// Wraps a `MontyWasm` platform and serializes execution through [_mutex].
///
/// `DefaultMontyBridge._isExecuting` already guards single-bridge concurrency.
/// This wrapper guards cross-bridge concurrency — multiple threads sharing
/// the same `window.DartMontyBridge` JS singleton.
class _MutexGuardedPlatform implements MontyPlatform {
  _MutexGuardedPlatform(this._inner);

  final MontyWasm _inner;

  @override
  Future<MontyResult> run(
    String code, {
    Map<String, Object?>? inputs,
    MontyLimits? limits,
    String? scriptName,
  }) async {
    await _mutex.acquire();
    try {
      return await _inner.run(
        code,
        inputs: inputs,
        limits: limits,
        scriptName: scriptName,
      );
    } finally {
      _mutex.release();
    }
  }

  @override
  Future<MontyProgress> start(
    String code, {
    Map<String, Object?>? inputs,
    List<String>? externalFunctions,
    MontyLimits? limits,
    String? scriptName,
  }) async {
    await _mutex.acquire();
    try {
      return await _inner.start(
        code,
        inputs: inputs,
        externalFunctions: externalFunctions,
        limits: limits,
        scriptName: scriptName,
      );
    } finally {
      _mutex.release();
    }
  }

  @override
  Future<MontyProgress> resume(Object? returnValue) async {
    await _mutex.acquire();
    try {
      return await _inner.resume(returnValue);
    } finally {
      _mutex.release();
    }
  }

  @override
  Future<MontyProgress> resumeWithError(String errorMessage) async {
    await _mutex.acquire();
    try {
      return await _inner.resumeWithError(errorMessage);
    } finally {
      _mutex.release();
    }
  }

  @override
  Future<void> dispose() => _inner.dispose();
}

/// Simple async mutex for serializing access to the shared JS bridge.
class _WebMutex {
  Completer<void>? _lock;

  /// Acquires the mutex. Returns when the lock is available.
  Future<void> acquire() async {
    while (_lock != null) {
      await _lock!.future;
    }
    _lock = Completer<void>();
  }

  /// Releases the mutex.
  void release() {
    final completer = _lock;
    _lock = null;
    completer?.complete();
  }
}
