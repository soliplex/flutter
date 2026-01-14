import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/design/design.dart';

/// Widget that displays a single chat message.
class ChatMessageWidget extends StatelessWidget {
  const ChatMessageWidget({
    required this.message,
    this.isStreaming = false,
    super.key,
  });

  final ChatMessage message;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soliplexTheme = SoliplexTheme.of(context);

    if (message.user == ChatUser.system) {
      return _buildSystemMessage(context, theme);
    }

    final isUser = message.user == ChatUser.user;
    final text = switch (message) {
      TextMessage(:final text) => text,
      ErrorMessage(:final errorText) => errorText,
      _ => '',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: min(600, MediaQuery.of(context).size.width * 0.8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(
                  soliplexTheme.radii.lg,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    Text(
                      text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: message is ErrorMessage
                            ? theme.colorScheme.error
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                    )
                  else
                    MarkdownBody(
                      data: text,
                      styleSheet: MarkdownStyleSheet(
                        p: theme.textTheme.bodyLarge?.copyWith(
                          color: message is ErrorMessage
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurface,
                        ),
                        code: context.monospace.copyWith(
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHigh,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            soliplexTheme.radii.sm,
                          ),
                        ),
                      ),
                      builders: {
                        'code': CodeBlockBuilder(
                          preferredStyle:
                              context.monospace.copyWith(fontSize: 14),
                        ),
                      },
                    ),
                  if (isStreaming) ...[
                    const SizedBox(height: 8),
                    _buildStreamingIndicator(context, theme),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context, ThemeData theme) {
    final text = switch (message) {
      TextMessage(:final text) => text,
      ErrorMessage(:final errorText) => errorText,
      _ => '',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(
              SoliplexTheme.of(context).radii.md,
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreamingIndicator(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Typing...',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

/// Custom markdown builder for code blocks with syntax highlighting.
class CodeBlockBuilder extends MarkdownElementBuilder {
  CodeBlockBuilder({required this.preferredStyle});

  final TextStyle preferredStyle;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent;
    var language = '';

    // Get language from class attribute (e.g., "language-dart")
    if (element.attributes['class'] != null) {
      final className = element.attributes['class']!;
      language = className.replaceFirst('language-', '');
    }

    final semanticLabel = language.isEmpty || language == 'plaintext'
        ? 'Code block'
        : 'Code block in $language';

    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: HighlightView(
          code,
          language: language.isEmpty ? 'plaintext' : language,
          theme: githubTheme,
          padding: EdgeInsets.zero,
          textStyle: preferredStyle,
        ),
      ),
    );
  }
}
