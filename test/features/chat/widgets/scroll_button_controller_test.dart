import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/features/chat/widgets/scroll_button_controller.dart';

void main() {
  late ScrollButtonController controller;

  setUp(() {
    controller = ScrollButtonController();
  });

  tearDown(() {
    controller.dispose();
  });

  group('initial state', () {
    test('button is not visible', () {
      expect(controller.isVisible.value, isFalse);
    });
  });

  group('scheduleAppearance', () {
    test('shows button after 300ms when not at bottom', () {
      fakeAsync((async) {
        controller
          ..updateScrollPosition(isAtBottom: false)
          ..scheduleAppearance();

        async.elapse(const Duration(milliseconds: 299));
        expect(controller.isVisible.value, isFalse);

        async.elapse(const Duration(milliseconds: 1));
        expect(controller.isVisible.value, isTrue);
      });
    });

    test('auto-hides button after 3 seconds', () {
      fakeAsync((async) {
        controller
          ..updateScrollPosition(isAtBottom: false)
          ..scheduleAppearance();

        async.elapse(const Duration(milliseconds: 300));
        expect(controller.isVisible.value, isTrue);

        async.elapse(const Duration(seconds: 3));
        expect(controller.isVisible.value, isFalse);
      });
    });

    test('is a no-op when at bottom', () {
      fakeAsync((async) {
        controller.scheduleAppearance();

        async.elapse(const Duration(seconds: 5));
        expect(controller.isVisible.value, isFalse);
      });
    });

    test('cancels existing timer before scheduling new one', () {
      fakeAsync((async) {
        controller
          ..updateScrollPosition(isAtBottom: false)
          ..scheduleAppearance();

        // Advance 200ms, then reschedule — first timer is cancelled.
        async.elapse(const Duration(milliseconds: 200));
        controller.scheduleAppearance();

        // 100ms from first schedule would have fired, but was cancelled.
        async.elapse(const Duration(milliseconds: 100));
        expect(controller.isVisible.value, isFalse);

        // Full 300ms from second schedule.
        async.elapse(const Duration(milliseconds: 200));
        expect(controller.isVisible.value, isTrue);
      });
    });
  });

  group('updateScrollPosition', () {
    test('cancels show timer when scrolled back to bottom', () {
      fakeAsync((async) {
        controller
          ..updateScrollPosition(isAtBottom: false)
          ..scheduleAppearance();

        async.elapse(const Duration(milliseconds: 200));
        controller.updateScrollPosition(isAtBottom: true);

        async.elapse(const Duration(milliseconds: 200));
        expect(controller.isVisible.value, isFalse);
      });
    });
  });

  group('hide', () {
    test('hides immediately and cancels timers', () {
      fakeAsync((async) {
        controller
          ..updateScrollPosition(isAtBottom: false)
          ..scheduleAppearance();

        async.elapse(const Duration(milliseconds: 300));
        expect(controller.isVisible.value, isTrue);

        controller.hide();
        expect(controller.isVisible.value, isFalse);

        // Auto-hide timer should also be cancelled (no error).
        async.elapse(const Duration(seconds: 5));
        expect(controller.isVisible.value, isFalse);
      });
    });

    test('is safe to call when already hidden', () {
      controller.hide();
      expect(controller.isVisible.value, isFalse);
    });

    test('cancels pending show timer before button becomes visible', () {
      fakeAsync((async) {
        controller
          ..updateScrollPosition(isAtBottom: false)
          ..scheduleAppearance();

        async.elapse(const Duration(milliseconds: 200));
        controller.hide();

        async.elapse(const Duration(milliseconds: 200));
        expect(controller.isVisible.value, isFalse);
      });
    });
  });

  group('dispose', () {
    test('cancels pending timers', () {
      fakeAsync((async) {
        // Use a separate instance so tearDown doesn't double-dispose.
        ScrollButtonController()
          ..updateScrollPosition(isAtBottom: false)
          ..scheduleAppearance()
          ..dispose();

        // No timer fires and no errors thrown.
        async.elapse(const Duration(seconds: 5));
      });
    });
  });
}
