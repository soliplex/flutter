import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/features/chat/widgets/anchored_scroll_controller.dart';
import 'package:soliplex_frontend/features/chat/widgets/scroll_to_message_session.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  late AnchoredScrollController controller;
  late ScrollToMessageSession session;
  late List<ChatMessage> messages;

  setUp(() {
    controller = AnchoredScrollController();
    session = ScrollToMessageSession(controller: controller);
    messages = [
      TestData.createMessage(id: 'msg-1'),
      TestData.createMessage(id: 'msg-2'),
      TestData.createMessage(id: 'msg-3'),
    ];
  });

  tearDown(() {
    controller.dispose();
  });

  group('shouldScrollTo', () {
    test('returns true for a new message present in the list', () {
      expect(session.shouldScrollTo('msg-2', messages), isTrue);
    });

    test('returns false for a message not in the list', () {
      expect(
        session.shouldScrollTo('msg-unknown', messages),
        isFalse,
      );
    });

    test('returns false for the same id already scrolled to', () {
      session
        ..scheduleFor('msg-1')
        ..finish();

      expect(session.shouldScrollTo('msg-1', messages), isFalse);
    });

    test('returns false while a scroll is already scheduled', () {
      session.scheduleFor('msg-1');

      expect(session.shouldScrollTo('msg-2', messages), isFalse);
    });
  });

  group('scheduleFor', () {
    test('sets targetMessageId and marks as scheduled', () {
      session.scheduleFor('msg-1');

      expect(session.targetMessageId, 'msg-1');
    });

    test('overwrites target when called while already scheduled', () {
      session
        ..scheduleFor('msg-1')
        ..scheduleFor('msg-2');

      expect(session.targetMessageId, 'msg-2');
    });

    test('clears a previously set targetScrollOffset', () {
      session
        ..scheduleFor('msg-1')
        ..targetScrollOffset = 200.0
        ..scheduleFor('msg-2');

      expect(session.targetScrollOffset, isNull);
    });
  });

  group('finish', () {
    test('clears targetMessageId', () {
      session
        ..scheduleFor('msg-1')
        ..finish();

      expect(session.targetMessageId, isNull);
    });

    test('preserves lastScrolledId so same id is not re-scrolled', () {
      session
        ..scheduleFor('msg-1')
        ..finish();

      expect(session.shouldScrollTo('msg-1', messages), isFalse);
    });

    test('allows scheduling a different message afterwards', () {
      session
        ..scheduleFor('msg-1')
        ..finish();

      expect(session.shouldScrollTo('msg-2', messages), isTrue);
    });

    test('preserves targetScrollOffset', () {
      session
        ..scheduleFor('msg-1')
        ..targetScrollOffset = 150.0
        ..finish();

      expect(session.targetScrollOffset, equals(150.0));
    });
  });

  group('markContentFilled / tryReleaseContentFilled', () {
    test('tryReleaseContentFilled returns false when not marked', () {
      session.scheduleFor('msg-1');

      expect(session.tryReleaseContentFilled(), isFalse);
      expect(session.targetScrollOffset, isNull);
    });

    test('tryReleaseContentFilled clears targetScrollOffset when marked', () {
      session
        ..scheduleFor('msg-1')
        ..targetScrollOffset = 200.0
        ..markContentFilled();

      expect(session.tryReleaseContentFilled(), isTrue);
      expect(session.targetScrollOffset, isNull);
    });

    test('tryReleaseContentFilled returns false on second call', () {
      session
        ..scheduleFor('msg-1')
        ..markContentFilled();

      // First call releases.
      expect(session.tryReleaseContentFilled(), isTrue);
      // Second call has nothing to release.
      expect(session.tryReleaseContentFilled(), isFalse);
    });

    test('scheduleFor resets contentFilled state', () {
      session
        ..scheduleFor('msg-1')
        ..targetScrollOffset = 200.0
        ..markContentFilled()
        ..scheduleFor('msg-2');

      expect(session.tryReleaseContentFilled(), isFalse);
    });
  });

  group('keyFor', () {
    test('returns the scrollKey for the target message', () {
      final scrollKey = GlobalKey();
      session.scheduleFor('msg-1');

      expect(session.keyFor('msg-1', scrollKey), same(scrollKey));
    });

    test('returns a ValueKey for non-target messages', () {
      final scrollKey = GlobalKey();
      session.scheduleFor('msg-1');

      expect(
        session.keyFor('msg-2', scrollKey),
        equals(const ValueKey('msg-2')),
      );
    });

    test('returns a ValueKey when no target is set', () {
      final scrollKey = GlobalKey();

      expect(
        session.keyFor('msg-1', scrollKey),
        equals(const ValueKey('msg-1')),
      );
    });
  });

  group('anchor sync', () {
    test('setting targetScrollOffset updates controller anchorOffset', () {
      session.targetScrollOffset = 300.0;
      expect(controller.anchorOffset, equals(300.0));
    });

    test('clearing targetScrollOffset clears controller anchorOffset', () {
      session
        ..targetScrollOffset = 300.0
        ..targetScrollOffset = null;

      expect(controller.anchorOffset, isNull);
    });

    test('scheduleFor clears controller anchorOffset', () {
      session
        ..scheduleFor('msg-1')
        ..targetScrollOffset = 200.0;

      expect(controller.anchorOffset, equals(200.0));

      session.scheduleFor('msg-2');

      expect(controller.anchorOffset, isNull);
    });

    test('tryReleaseContentFilled clears controller anchorOffset', () {
      session
        ..scheduleFor('msg-1')
        ..targetScrollOffset = 200.0
        ..markContentFilled();

      expect(session.tryReleaseContentFilled(), isTrue);
      expect(controller.anchorOffset, isNull);
    });
  });
}
