import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:soliplex_client/soliplex_client.dart';

import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/chat/widgets/code_block_builder.dart';

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
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        spacing: SoliplexSpacing.s2,
        children: [
          Container(
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
                        backgroundColor: theme.colorScheme.surfaceContainerHigh,
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
          if (isUser)
            _buildUserMessageActionsRow(
              context,
              theme,
              messageText: text,
            )
          else if (!isUser && !isStreaming)
            _buildAgentMessageActionsRow(
              context,
              theme,
              messageText: text,
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

  // TODO: Remove this comment
  // NOTE: I stubbed branch selection both for user and agent messages because 
  // user can trigger branching both with edits and regeneration.

  Widget _buildUserMessageActionsRow(
    BuildContext context,
    ThemeData theme, {
    required String messageText,
    int selectedBranch = 0,
    int totalBranches = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        top: SoliplexSpacing.s1,
        right: SoliplexSpacing.s3,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: SoliplexSpacing.s2,
        children: [
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: messageText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Message copied to clipboard'),
                ),
              );
            },
            child: Icon(
              Icons.copy,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (totalBranches != 0) ...[
            if (selectedBranch > 0)
              InkWell(
                onTap: () => {
                  // TODO: Implement branch selection logic
                },
                child: Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (selectedBranch < totalBranches)
              InkWell(
                onTap: () => {
                  // TODO: Implement branch selection logic
                },
                child: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
          InkWell(
            onTap: () => {
              // TODO: Implement edit message logic
            },
            child: Icon(
              Icons.edit,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentMessageActionsRow(
    BuildContext context,
    ThemeData theme, {
    required String messageText,
    int selectedBranch = 0,
    int totalBranches = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        top: SoliplexSpacing.s1,
        left: SoliplexSpacing.s3,
      ),
      child: Row(
        spacing: SoliplexSpacing.s2,
        children: [
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: messageText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Message copied to clipboard'),
                ),
              );
            },
            child: Icon(
              Icons.copy,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          InkWell(
            onTap: () => {
              // TODO: Implement regeneration logic
            },
            child: Icon(
              Icons.repeat,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (totalBranches != 0) ...[
            if (selectedBranch > 0)
              InkWell(
                onTap: () => {
                  // TODO: Implement branch selection logic
                },
                child: Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (selectedBranch < totalBranches)
              InkWell(
                onTap: () => {
                  // TODO: Implement branch selection logic
                },
                child: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
          InkWell(
            onTap: () => {
              // TODO: Implement feedback logic
            },
            child: Icon(
              Icons.thumb_up,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          InkWell(
            onTap: () => {
              // TODO: Implement feedback logic
            },
            child: Icon(
              Icons.thumb_down,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
