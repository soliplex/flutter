import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/features/chat/widgets/scroll_to_message_session.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  late ScrollToMessageSession session;
  late List<ChatMessage> messages;

  setUp(() {
    session = ScrollToMessageSession();
    messages = [
      TestData.createMessage(id: 'msg-1'),
      TestData.createMessage(id: 'msg-2'),
      TestData.createMessage(id: 'msg-3'),
    ];
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
}
