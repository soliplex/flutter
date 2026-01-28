import 'package:soliplex_client/src/application/streaming_state.dart';
import 'package:test/test.dart';

void main() {
  group('ToolCallActivity', () {
    test('withToolName accumulates tool names from single-tool constructor',
        () {
      const activity = ToolCallActivity(toolName: 'search');

      final updated = activity.withToolName('summarize');

      expect(updated.allToolNames, equals({'search', 'summarize'}));
    });

    test('withToolName accumulates tool names from multiple-tool constructor',
        () {
      const activity = ToolCallActivity.multiple(toolNames: {'a', 'b'});

      final updated = activity.withToolName('c');

      expect(updated.allToolNames, equals({'a', 'b', 'c'}));
    });

    test('withToolName is idempotent for duplicate names', () {
      const activity = ToolCallActivity(toolName: 'search');

      final updated = activity.withToolName('search');

      expect(updated.allToolNames, equals({'search'}));
    });

    test('equality works across constructor variants', () {
      const single = ToolCallActivity(toolName: 'search');
      const multiple = ToolCallActivity.multiple(toolNames: {'search'});

      expect(single, equals(multiple));
    });
  });

  group('AwaitingText', () {
    test('hasThinkingContent is true when bufferedThinkingText is non-empty',
        () {
      const state = AwaitingText(bufferedThinkingText: 'Thinking...');

      expect(state.hasThinkingContent, isTrue);
    });

    test('hasThinkingContent is true when isThinkingStreaming', () {
      const state = AwaitingText(isThinkingStreaming: true);

      expect(state.hasThinkingContent, isTrue);
    });

    test('hasThinkingContent is false when no thinking content', () {
      const state = AwaitingText();

      expect(state.hasThinkingContent, isFalse);
    });
  });
}
