import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/application/run_lifecycle_impl.dart';
import 'package:soliplex_frontend/core/domain/interfaces/screen_wake_lock.dart';

/// Mock ScreenWakeLock that tracks calls.
class MockScreenWakeLock implements ScreenWakeLock {
  int enableCallCount = 0;
  int disableCallCount = 0;
  bool _isEnabled = false;

  @override
  bool get isEnabled => _isEnabled;

  @override
  Future<void> enable() async {
    enableCallCount++;
    _isEnabled = true;
  }

  @override
  Future<void> disable() async {
    disableCallCount++;
    _isEnabled = false;
  }

  void reset() {
    enableCallCount = 0;
    disableCallCount = 0;
    _isEnabled = false;
  }
}

void main() {
  late MockScreenWakeLock mockWakeLock;
  late RunLifecycleImpl runLifecycle;

  setUp(() {
    mockWakeLock = MockScreenWakeLock();
    runLifecycle = RunLifecycleImpl(wakeLock: mockWakeLock);
  });

  group('RunLifecycleImpl', () {
    group('single run', () {
      test('enables wake lock when run starts', () {
        runLifecycle.onRunStarted('run-1');

        expect(mockWakeLock.enableCallCount, equals(1));
        expect(mockWakeLock.isEnabled, isTrue);
      });

      test('disables wake lock when run ends', () {
        runLifecycle.onRunStarted('run-1');
        mockWakeLock.reset();

        runLifecycle.onRunEnded('run-1');

        expect(mockWakeLock.disableCallCount, equals(1));
        expect(mockWakeLock.isEnabled, isFalse);
      });

      test('start then end sequence enables then disables', () {
        runLifecycle.onRunStarted('run-1');
        expect(mockWakeLock.enableCallCount, equals(1));

        runLifecycle.onRunEnded('run-1');
        expect(mockWakeLock.disableCallCount, equals(1));
      });
    });

    group('multiple concurrent runs (reference counting)', () {
      test('keeps wake lock enabled when second run starts', () {
        runLifecycle.onRunStarted('run-1');
        expect(mockWakeLock.enableCallCount, equals(1));

        runLifecycle.onRunStarted('run-2');
        // Should not call enable again
        expect(mockWakeLock.enableCallCount, equals(1));
        expect(mockWakeLock.isEnabled, isTrue);
      });

      test('keeps wake lock enabled when first of two runs ends', () {
        runLifecycle
          ..onRunStarted('run-1')
          ..onRunStarted('run-2')
          ..onRunEnded('run-1');

        // Should not disable yet
        expect(mockWakeLock.disableCallCount, equals(0));
        expect(mockWakeLock.isEnabled, isTrue);
      });

      test('disables wake lock only when last run ends', () {
        runLifecycle
          ..onRunStarted('run-1')
          ..onRunStarted('run-2')
          ..onRunEnded('run-1');

        expect(mockWakeLock.disableCallCount, equals(0));

        runLifecycle.onRunEnded('run-2');
        expect(mockWakeLock.disableCallCount, equals(1));
        expect(mockWakeLock.isEnabled, isFalse);
      });

      test('three concurrent runs: disabled only when all end', () {
        runLifecycle
          ..onRunStarted('run-1')
          ..onRunStarted('run-2')
          ..onRunStarted('run-3');

        expect(mockWakeLock.enableCallCount, equals(1));

        runLifecycle.onRunEnded('run-2');
        expect(mockWakeLock.disableCallCount, equals(0));

        runLifecycle.onRunEnded('run-1');
        expect(mockWakeLock.disableCallCount, equals(0));

        runLifecycle.onRunEnded('run-3');
        expect(mockWakeLock.disableCallCount, equals(1));
      });
    });

    group('idempotency and edge cases', () {
      test('ending same run twice does not crash or double-disable', () {
        runLifecycle
          ..onRunStarted('run-1')
          ..onRunEnded('run-1');
        expect(mockWakeLock.disableCallCount, equals(1));

        // Second end should be a no-op
        runLifecycle.onRunEnded('run-1');
        expect(mockWakeLock.disableCallCount, equals(1));
      });

      test('ending unknown run does not crash or affect state', () {
        runLifecycle
          ..onRunStarted('run-1')
          // End a run that was never started
          ..onRunEnded('unknown-run');

        // Wake lock should still be enabled
        expect(mockWakeLock.isEnabled, isTrue);
        expect(mockWakeLock.disableCallCount, equals(0));
      });

      test('starting same run twice only enables once', () {
        runLifecycle
          ..onRunStarted('run-1')
          ..onRunStarted('run-1');

        // Second start with same ID is idempotent (Set behavior)
        expect(mockWakeLock.enableCallCount, equals(1));
      });

      test('re-enable after all runs complete', () {
        runLifecycle
          ..onRunStarted('run-1')
          ..onRunEnded('run-1');

        expect(mockWakeLock.disableCallCount, equals(1));

        // Start a new run after complete cycle
        runLifecycle.onRunStarted('run-2');
        expect(mockWakeLock.enableCallCount, equals(2));
        expect(mockWakeLock.isEnabled, isTrue);
      });
    });
  });
}
