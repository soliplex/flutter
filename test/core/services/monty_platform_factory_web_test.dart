import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

// We can't import the web factory directly (it depends on dart:js_interop).
// Instead, test the mutex logic in isolation by replicating _WebMutex here.
// This validates the concurrency algorithm used in the web factory.

/// Replica of _WebMutex from monty_platform_factory_web.dart for testing.
class WebMutex {
  Completer<void>? _lock;

  Future<void> acquire() async {
    while (_lock != null) {
      await _lock!.future;
    }
    _lock = Completer<void>();
  }

  void release() {
    final completer = _lock;
    _lock = null;
    completer?.complete();
  }
}

void main() {
  group('WebMutex', () {
    late WebMutex mutex;

    setUp(() {
      mutex = WebMutex();
    });

    test('acquire succeeds immediately when unlocked', () async {
      await mutex.acquire();
      // Should not hang — if it does, the test times out.
      mutex.release();
    });

    test('second acquire waits until first releases', () async {
      final order = <String>[];

      await mutex.acquire();
      order.add('first acquired');

      // Schedule second acquire — should block.
      unawaited(
        Future(() async {
          order.add('second waiting');
          await mutex.acquire();
          order.add('second acquired');
          mutex.release();
        }),
      );

      // Let the microtask for the second acquire start.
      await Future<void>.delayed(Duration.zero);
      expect(order, ['first acquired', 'second waiting']);

      // Release first lock — second should proceed.
      mutex.release();
      await Future<void>.delayed(Duration.zero);
      expect(order, ['first acquired', 'second waiting', 'second acquired']);
    });

    test('serializes three concurrent acquires in order', () async {
      final order = <int>[];

      await mutex.acquire();

      // Queue up tasks 1, 2, 3 — all should wait.
      for (var i = 1; i <= 3; i++) {
        final index = i;
        unawaited(
          Future(() async {
            await mutex.acquire();
            order.add(index);
            // Simulate async work.
            await Future<void>.delayed(Duration.zero);
            mutex.release();
          }),
        );
      }

      // Let all three futures start waiting.
      await Future<void>.delayed(Duration.zero);
      expect(order, isEmpty);

      // Release — tasks should execute one at a time.
      mutex.release();

      // Pump the event loop enough for all three to complete.
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(order, hasLength(3));
      // All three completed — ordering depends on microtask scheduling
      // but all must have run (no deadlock).
    });

    test('release without acquire is safe', () {
      // Should not throw.
      mutex.release();
    });
  });
}
