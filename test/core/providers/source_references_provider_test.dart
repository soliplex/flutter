import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/source_references_provider.dart';
import 'package:soliplex_frontend/core/providers/thread_history_cache.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('sourceReferencesForUserMessageProvider', () {
    test('returns empty list when userMessageId is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final refs = container.read(
        sourceReferencesForUserMessageProvider(null),
      );

      expect(refs, isEmpty);
    });

    test('returns source references from active run conversation', () {
      // Arrange: Create conversation with messageStates
      const sourceRef = SourceReference(
        documentId: 'doc-1',
        documentUri: 'https://example.com/doc.pdf',
        content: 'Test content',
        chunkId: 'chunk-1',
      );
      final messageState = MessageState(
        userMessageId: 'user_123',
        sourceReferences: const [sourceRef],
      );
      final conversation = Conversation(
        threadId: 'thread-1',
        status: const Completed(),
        messageStates: {'user_123': messageState},
      );

      final container = ProviderContainer(
        overrides: [
          activeRunNotifierOverride(
            CompletedState(
              conversation: conversation,
              result: const Success(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final refs = container.read(
        sourceReferencesForUserMessageProvider('user_123'),
      );

      // Assert
      expect(refs, hasLength(1));
      expect(refs.first.documentId, 'doc-1');
    });

    test('returns source references from cache when no active run', () {
      // Arrange: Create cached history with messageStates
      const sourceRef = SourceReference(
        documentId: 'doc-2',
        documentUri: 'https://example.com/cached.pdf',
        content: 'Cached content',
        chunkId: 'chunk-2',
      );
      final messageState = MessageState(
        userMessageId: 'user_456',
        sourceReferences: const [sourceRef],
      );
      final cachedHistory = ThreadHistory(
        messages: const [],
        messageStates: {'user_456': messageState},
      );

      final container = ProviderContainer(
        overrides: [
          activeRunNotifierOverride(const IdleState()),
          currentRoomIdProviderOverride('room-1'),
          threadSelectionProviderOverride(const ThreadSelected('thread-1')),
        ],
      );
      addTearDown(container.dispose);

      // Pre-populate cache
      container.read(threadHistoryCacheProvider.notifier).updateHistory(
        const (roomId: 'room-1', threadId: 'thread-1'),
        cachedHistory,
      );

      // Act
      final refs = container.read(
        sourceReferencesForUserMessageProvider('user_456'),
      );

      // Assert
      expect(refs, hasLength(1));
      expect(refs.first.documentId, 'doc-2');
    });

    test('returns empty list when userMessageId not in messageStates', () {
      final container = ProviderContainer(
        overrides: [
          activeRunNotifierOverride(const IdleState()),
          currentRoomIdProviderOverride('room-1'),
          threadSelectionProviderOverride(const ThreadSelected('thread-1')),
        ],
      );
      addTearDown(container.dispose);

      // Pre-populate cache with empty messageStates
      container.read(threadHistoryCacheProvider.notifier).updateHistory(
        const (roomId: 'room-1', threadId: 'thread-1'),
        ThreadHistory(messages: const []),
      );

      // Act
      final refs = container.read(
        sourceReferencesForUserMessageProvider('nonexistent'),
      );

      // Assert
      expect(refs, isEmpty);
    });

    test('returns empty list when no thread selected and idle', () {
      final container = ProviderContainer(
        overrides: [
          activeRunNotifierOverride(const IdleState()),
          threadSelectionProviderOverride(const NoThreadSelected()),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final refs = container.read(
        sourceReferencesForUserMessageProvider('user_123'),
      );

      // Assert
      expect(refs, isEmpty);
    });

    test('prefers active run over cache when both have data', () {
      // Arrange: Both active run and cache have different data
      const activeRef = SourceReference(
        documentId: 'active-doc',
        documentUri: 'https://example.com/active.pdf',
        content: 'Active content',
        chunkId: 'chunk-active',
      );
      const cachedRef = SourceReference(
        documentId: 'cached-doc',
        documentUri: 'https://example.com/cached.pdf',
        content: 'Cached content',
        chunkId: 'chunk-cached',
      );

      final activeConversation = Conversation(
        threadId: 'thread-1',
        status: const Running(runId: 'run-1'),
        messageStates: {
          'user_123': MessageState(
            userMessageId: 'user_123',
            sourceReferences: const [activeRef],
          ),
        },
      );

      final cachedHistory = ThreadHistory(
        messages: const [],
        messageStates: {
          'user_123': MessageState(
            userMessageId: 'user_123',
            sourceReferences: const [cachedRef],
          ),
        },
      );

      final container = ProviderContainer(
        overrides: [
          activeRunNotifierOverride(
            RunningState(conversation: activeConversation),
          ),
          currentRoomIdProviderOverride('room-1'),
          threadSelectionProviderOverride(const ThreadSelected('thread-1')),
        ],
      );
      addTearDown(container.dispose);

      // Pre-populate cache
      container.read(threadHistoryCacheProvider.notifier).updateHistory(
        const (roomId: 'room-1', threadId: 'thread-1'),
        cachedHistory,
      );

      // Act
      final refs = container.read(
        sourceReferencesForUserMessageProvider('user_123'),
      );

      // Assert: Should get active run data, not cached
      expect(refs, hasLength(1));
      expect(refs.first.documentId, 'active-doc');
    });
  });
}
