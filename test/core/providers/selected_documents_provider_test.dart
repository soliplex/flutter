import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/selected_documents_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('SelectedDocumentsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty map', () {
      final state = container.read(selectedDocumentsNotifierProvider);
      expect(state, isEmpty);
    });

    test('setForThread stores documents for specific thread', () {
      final doc = TestData.createDocument(id: 'doc-1', title: 'Doc 1');
      container
          .read(selectedDocumentsNotifierProvider.notifier)
          .setForThread('room-1', 'thread-1', {doc});

      final state = container.read(selectedDocumentsNotifierProvider);
      expect(state[(roomId: 'room-1', threadId: 'thread-1')], equals({doc}));
    });

    test('getForThread returns documents for specific thread', () {
      final doc = TestData.createDocument(id: 'doc-1', title: 'Doc 1');
      final notifier = container
          .read(selectedDocumentsNotifierProvider.notifier)
        ..setForThread('room-1', 'thread-1', {doc});

      final result = notifier.getForThread('room-1', 'thread-1');
      expect(result, equals({doc}));
    });

    test('getForThread returns empty set for unknown thread', () {
      final notifier =
          container.read(selectedDocumentsNotifierProvider.notifier);
      final result = notifier.getForThread('room-1', 'unknown-thread');
      expect(result, isEmpty);
    });

    test('different threads have independent selections', () {
      final doc1 = TestData.createDocument(id: 'doc-1', title: 'Doc 1');
      final doc2 = TestData.createDocument(id: 'doc-2', title: 'Doc 2');
      final notifier =
          container.read(selectedDocumentsNotifierProvider.notifier)
            ..setForThread('room-1', 'thread-1', {doc1})
            ..setForThread('room-1', 'thread-2', {doc2});

      expect(notifier.getForThread('room-1', 'thread-1'), equals({doc1}));
      expect(notifier.getForThread('room-1', 'thread-2'), equals({doc2}));
    });

    test('different rooms have independent selections', () {
      final doc1 = TestData.createDocument(id: 'doc-1', title: 'Doc 1');
      final doc2 = TestData.createDocument(id: 'doc-2', title: 'Doc 2');
      final notifier =
          container.read(selectedDocumentsNotifierProvider.notifier)
            ..setForThread('room-1', 'thread-1', {doc1})
            ..setForThread('room-2', 'thread-1', {doc2});

      expect(notifier.getForThread('room-1', 'thread-1'), equals({doc1}));
      expect(notifier.getForThread('room-2', 'thread-1'), equals({doc2}));
    });

    test('setForThread replaces existing selection', () {
      final doc1 = TestData.createDocument(id: 'doc-1', title: 'Doc 1');
      final doc2 = TestData.createDocument(id: 'doc-2', title: 'Doc 2');
      final notifier =
          container.read(selectedDocumentsNotifierProvider.notifier)
            ..setForThread('room-1', 'thread-1', {doc1})
            ..setForThread('room-1', 'thread-1', {doc2});

      expect(notifier.getForThread('room-1', 'thread-1'), equals({doc2}));
    });

    test('clearForThread removes selection for specific thread', () {
      final doc = TestData.createDocument(id: 'doc-1', title: 'Doc 1');
      final notifier =
          container.read(selectedDocumentsNotifierProvider.notifier)
            ..setForThread('room-1', 'thread-1', {doc})
            ..clearForThread('room-1', 'thread-1');

      expect(notifier.getForThread('room-1', 'thread-1'), isEmpty);
    });

    test('clearForThread does not affect other threads', () {
      final doc1 = TestData.createDocument(id: 'doc-1', title: 'Doc 1');
      final doc2 = TestData.createDocument(id: 'doc-2', title: 'Doc 2');
      final notifier =
          container.read(selectedDocumentsNotifierProvider.notifier)
            ..setForThread('room-1', 'thread-1', {doc1})
            ..setForThread('room-1', 'thread-2', {doc2})
            ..clearForThread('room-1', 'thread-1');

      expect(notifier.getForThread('room-1', 'thread-1'), isEmpty);
      expect(notifier.getForThread('room-1', 'thread-2'), equals({doc2}));
    });

    test('clearForRoom removes all selections for room', () {
      final doc1 = TestData.createDocument(id: 'doc-1', title: 'Doc 1');
      final doc2 = TestData.createDocument(id: 'doc-2', title: 'Doc 2');
      final notifier =
          container.read(selectedDocumentsNotifierProvider.notifier)
            ..setForThread('room-1', 'thread-1', {doc1})
            ..setForThread('room-1', 'thread-2', {doc2})
            ..clearForRoom('room-1');

      expect(notifier.getForThread('room-1', 'thread-1'), isEmpty);
      expect(notifier.getForThread('room-1', 'thread-2'), isEmpty);
    });

    test('clearForRoom does not affect other rooms', () {
      final doc1 = TestData.createDocument(id: 'doc-1', title: 'Doc 1');
      final doc2 = TestData.createDocument(id: 'doc-2', title: 'Doc 2');
      final notifier =
          container.read(selectedDocumentsNotifierProvider.notifier)
            ..setForThread('room-1', 'thread-1', {doc1})
            ..setForThread('room-2', 'thread-1', {doc2})
            ..clearForRoom('room-1');

      expect(notifier.getForThread('room-1', 'thread-1'), isEmpty);
      expect(notifier.getForThread('room-2', 'thread-1'), equals({doc2}));
    });
  });

  group('currentSelectedDocumentsProvider', () {
    test('returns empty set when no room selected', () {
      final container = ProviderContainer(
        overrides: [
          currentRoomIdProvider.overrideWith(MockCurrentRoomIdNotifier.new),
          threadSelectionProviderOverride(const NoThreadSelected()),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(currentSelectedDocumentsProvider);
      expect(result, isEmpty);
    });

    test('returns empty set when no thread selected', () {
      final container = ProviderContainer(
        overrides: [
          currentRoomIdProviderOverride('room-1'),
          threadSelectionProviderOverride(const NoThreadSelected()),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(currentSelectedDocumentsProvider);
      expect(result, isEmpty);
    });

    test('returns selection for current thread', () {
      final doc = TestData.createDocument(id: 'doc-1', title: 'Doc 1');
      final container = ProviderContainer(
        overrides: [
          currentRoomIdProviderOverride('room-1'),
          threadSelectionProviderOverride(const ThreadSelected('thread-1')),
        ],
      );
      addTearDown(container.dispose);

      // Set up selection
      container
          .read(selectedDocumentsNotifierProvider.notifier)
          .setForThread('room-1', 'thread-1', {doc});

      final result = container.read(currentSelectedDocumentsProvider);
      expect(result, equals({doc}));
    });

    test('updates when thread selection changes', () {
      final doc1 = TestData.createDocument(id: 'doc-1', title: 'Doc 1');
      final doc2 = TestData.createDocument(id: 'doc-2', title: 'Doc 2');
      final container = ProviderContainer(
        overrides: [
          currentRoomIdProviderOverride('room-1'),
          threadSelectionProvider.overrideWith(
            () => MockThreadSelectionNotifier(
              initialSelection: const ThreadSelected('thread-1'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Set up selections for both threads
      container.read(selectedDocumentsNotifierProvider.notifier)
        ..setForThread('room-1', 'thread-1', {doc1})
        ..setForThread('room-1', 'thread-2', {doc2});

      // Verify initial selection
      expect(container.read(currentSelectedDocumentsProvider), equals({doc1}));

      // Switch threads
      container
          .read(threadSelectionProvider.notifier)
          .set(const ThreadSelected('thread-2'));

      // Verify selection changed
      expect(container.read(currentSelectedDocumentsProvider), equals({doc2}));
    });

    test('returns empty set for new thread (no existing selection)', () {
      final container = ProviderContainer(
        overrides: [
          currentRoomIdProviderOverride('room-1'),
          threadSelectionProviderOverride(const ThreadSelected('new-thread')),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(currentSelectedDocumentsProvider);
      expect(result, isEmpty);
    });
  });
}
