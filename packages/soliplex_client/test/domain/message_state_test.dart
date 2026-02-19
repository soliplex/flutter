import 'package:soliplex_client/src/domain/message_state.dart';
import 'package:soliplex_client/src/domain/source_reference.dart';
import 'package:test/test.dart';

void main() {
  group('MessageState', () {
    test('creates with empty source references', () {
      final state = MessageState(
        userMessageId: 'user-123',
        sourceReferences: const [],
      );

      expect(state.userMessageId, 'user-123');
      expect(state.sourceReferences, isEmpty);
      expect(state.runId, isNull);
    });

    test('creates with runId', () {
      final state = MessageState(
        userMessageId: 'user-123',
        sourceReferences: const [],
        runId: 'run-456',
      );

      expect(state.runId, 'run-456');
    });

    test('creates with source references', () {
      const refs = [
        SourceReference(
          documentId: 'doc-1',
          documentUri: 'https://example.com/doc1.pdf',
          content: 'Content 1',
          chunkId: 'chunk-1',
        ),
        SourceReference(
          documentId: 'doc-2',
          documentUri: 'https://example.com/doc2.pdf',
          content: 'Content 2',
          chunkId: 'chunk-2',
        ),
      ];

      final state = MessageState(
        userMessageId: 'user-123',
        sourceReferences: refs,
      );

      expect(state.userMessageId, 'user-123');
      expect(state.sourceReferences, hasLength(2));
      expect(state.sourceReferences[0].chunkId, 'chunk-1');
      expect(state.sourceReferences[1].chunkId, 'chunk-2');
    });

    group('equality', () {
      test('equal states are equal', () {
        final state1 = MessageState(
          userMessageId: 'user-123',
          sourceReferences: const [],
        );
        final state2 = MessageState(
          userMessageId: 'user-123',
          sourceReferences: const [],
        );

        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('different userMessageId makes states unequal', () {
        final state1 = MessageState(
          userMessageId: 'user-123',
          sourceReferences: const [],
        );
        final state2 = MessageState(
          userMessageId: 'user-456',
          sourceReferences: const [],
        );

        expect(state1, isNot(equals(state2)));
      });

      test('different runId makes states unequal', () {
        final state1 = MessageState(
          userMessageId: 'user-123',
          sourceReferences: const [],
          runId: 'run-1',
        );
        final state2 = MessageState(
          userMessageId: 'user-123',
          sourceReferences: const [],
          runId: 'run-2',
        );

        expect(state1, isNot(equals(state2)));
      });

      test('null and non-null runId makes states unequal', () {
        final state1 = MessageState(
          userMessageId: 'user-123',
          sourceReferences: const [],
        );
        final state2 = MessageState(
          userMessageId: 'user-123',
          sourceReferences: const [],
          runId: 'run-1',
        );

        expect(state1, isNot(equals(state2)));
      });

      test('different sourceReferences makes states unequal', () {
        const refs = [
          SourceReference(
            documentId: 'doc-1',
            documentUri: 'https://example.com/doc1.pdf',
            content: 'Content 1',
            chunkId: 'chunk-1',
          ),
        ];

        final state1 = MessageState(
          userMessageId: 'user-123',
          sourceReferences: const [],
        );
        final state2 = MessageState(
          userMessageId: 'user-123',
          sourceReferences: refs,
        );

        expect(state1, isNot(equals(state2)));
      });
    });

    group('immutability', () {
      test('sourceReferences list cannot be modified externally', () {
        final refs = <SourceReference>[
          const SourceReference(
            documentId: 'doc-1',
            documentUri: 'https://example.com/doc1.pdf',
            content: 'Content 1',
            chunkId: 'chunk-1',
          ),
        ];

        final state = MessageState(
          userMessageId: 'user-123',
          sourceReferences: refs,
        );

        // Modifying the original list should not affect the state
        refs.add(
          const SourceReference(
            documentId: 'doc-2',
            documentUri: 'https://example.com/doc2.pdf',
            content: 'Content 2',
            chunkId: 'chunk-2',
          ),
        );

        expect(state.sourceReferences, hasLength(1));
      });
    });
  });
}
