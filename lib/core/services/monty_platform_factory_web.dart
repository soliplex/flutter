import 'dart:async';

import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:dart_monty_wasm/dart_monty_wasm.dart';

/// Mutex that serializes MontyWasm creation and execution.
///
/// All [MontyWasm] instances share the `window.DartMontyBridge` JS singleton.
/// Dart on web is single-threaded, but interleaved async calls can corrupt
/// state. This mutex ensures only one platform operation runs at a time.
final _mutex = _WebMutex();

/// Creates a web [MontyPlatform] backed by WASM.
///
/// Returns a `MontyWasm` instance. Callers must be aware that all instances
/// share a single JS bridge — the [_WebMutex] in this module serializes
/// concurrent access at the factory level.
MontyPlatform createMontyPlatform() => MontyWasm(bindings: WasmBindingsJs());

/// Simple async mutex for serializing access to the shared JS bridge.
///
/// Used by higher-level code (e.g., bridge cache) to guard concurrent
/// `execute()` calls on web.
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

/// Guards a callback with the web execution mutex.
///
/// On web, all MontyWasm instances share a single JS bridge. This function
/// serializes access so interleaved async calls don't corrupt state.
///
/// Import this from the conditional factory — on native, it's a no-op.
Future<T> withWebMutex<T>(Future<T> Function() fn) async {
  await _mutex.acquire();
  try {
    return await fn();
  } finally {
    _mutex.release();
  }
}
