import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/providers/citations_expanded_provider.dart';

void main() {
  group('CitationsExpandedNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty set', () {
      final state = container.read(citationsExpandedProvider('thread-1'));

      expect(state, isEmpty);
    });

    test('toggle adds key when not present', () {
      container
          .read(citationsExpandedProvider('thread-1').notifier)
          .toggle('msg-1');

      final state = container.read(citationsExpandedProvider('thread-1'));

      expect(state, contains('msg-1'));
      expect(state.length, equals(1));
    });

    test('toggle removes key when already present', () {
      final notifier = container
          .read(citationsExpandedProvider('thread-1').notifier)
        ..toggle('msg-1');
      expect(
        container.read(citationsExpandedProvider('thread-1')),
        contains('msg-1'),
      );

      notifier.toggle('msg-1');
      expect(
        container.read(citationsExpandedProvider('thread-1')),
        isNot(contains('msg-1')),
      );
    });

    test('multiple keys can be tracked independently', () {
      container.read(citationsExpandedProvider('thread-1').notifier)
        ..toggle('msg-1')
        ..toggle('msg-2')
        ..toggle('msg-1:0');

      final state = container.read(citationsExpandedProvider('thread-1'));

      expect(state, containsAll(['msg-1', 'msg-2', 'msg-1:0']));
      expect(state.length, equals(3));
    });

    test('different threads have independent state', () {
      container
          .read(citationsExpandedProvider('thread-1').notifier)
          .toggle('msg-1');
      container
          .read(citationsExpandedProvider('thread-2').notifier)
          .toggle('msg-2');

      final state1 = container.read(citationsExpandedProvider('thread-1'));
      final state2 = container.read(citationsExpandedProvider('thread-2'));

      expect(state1, contains('msg-1'));
      expect(state1, isNot(contains('msg-2')));
      expect(state2, contains('msg-2'));
      expect(state2, isNot(contains('msg-1')));
    });

    test('state is immutable - creates new set on toggle', () {
      final notifier = container
          .read(citationsExpandedProvider('thread-1').notifier)
        ..toggle('msg-1');
      final state1 = container.read(citationsExpandedProvider('thread-1'));

      notifier.toggle('msg-2');
      final state2 = container.read(citationsExpandedProvider('thread-1'));

      expect(identical(state1, state2), isFalse);
      expect(state1.length, equals(1));
      expect(state2.length, equals(2));
    });
  });
}
