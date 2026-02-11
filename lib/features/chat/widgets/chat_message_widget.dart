import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:soliplex_client/soliplex_client.dart'
    show ChatMessage, ChatUser, ErrorMessage, SourceReference, TextMessage;

import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/chat/widgets/citations_section.dart';
import 'package:soliplex_frontend/shared/widgets/fullscreen_image_viewer.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/flutter_markdown_plus_renderer.dart';

import 'package:url_launcher/url_launcher.dart';

/// Widget that displays a single chat message.
class ChatMessageWidget extends StatelessWidget {
  const ChatMessageWidget({
    required this.message,
    this.isStreaming = false,
    this.isThinkingStreaming = false,
    this.sourceReferences = const [],
    super.key,
  });

  final ChatMessage message;
  final bool isStreaming;

  /// Whether thinking is currently streaming. Only meaningful for the synthetic
  /// streaming message; historical messages always have this as false.
  final bool isThinkingStreaming;

  /// Source references (citations) associated with this message.
  final List<SourceReference> sourceReferences;

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
    final thinkingText = switch (message) {
      TextMessage(:final thinkingText) => thinkingText,
      _ => '',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        spacing: SoliplexSpacing.s2,
        children: [
          // Show thinking section for assistant messages with thinking content
          if (!isUser && (thinkingText.isNotEmpty || isThinkingStreaming))
            Container(
              constraints: BoxConstraints(
                maxWidth: min(600, MediaQuery.of(context).size.width * 0.8),
              ),
              child: ThinkingSection(
                thinkingText: thinkingText,
                isStreaming: isThinkingStreaming,
              ),
            ),
          // Hide message bubble when text is empty and streaming (assistant
          // is still processing). The thinking section and status indicator
          // show what's happening.
          if (text.isNotEmpty || !isStreaming)
            SelectionArea(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: min(600, MediaQuery.of(context).size.width * 0.8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(soliplexTheme.radii.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isUser)
                      TextSelectionTheme(
                        data: TextSelectionThemeData(
                          selectionColor:
                              theme.colorScheme.onPrimaryContainer.withAlpha(
                            (0.4 * 255).toInt(),
                          ),
                          selectionHandleColor:
                              theme.colorScheme.onPrimaryContainer,
                        ),
                        child: Text(
                          text,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: message is ErrorMessage
                                ? theme.colorScheme.error
                                : theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      )
                    else
                      // NOTE: Do not set selectable: true here
                      // The markdown is rendered as separate widgets,
                      // if you set selectable: true, you'll have to select
                      // each widget separately.
                      FlutterMarkdownPlusRenderer(
                        data: text,
                        onLinkTap: _openLink,
                        onImageTap: (src, alt) => _openImage(
                          context,
                          src,
                          alt,
                        ),
                      ),
                    // Only show streaming indicator when there's actual text
                    // being streamed. When text is empty, the status indicator
                    // at the bottom of the list shows what's happening.
                    if (isStreaming && text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildStreamingIndicator(context, theme),
                    ],
                  ],
                ),
              ),
            ),
          if (isUser)
            _buildUserMessageActionsRow(
              context,
              messageText: text,
            )
          else ...[
            // Show citations section after the message for assistant messages
            if (sourceReferences.isNotEmpty)
              Container(
                constraints: BoxConstraints(
                  maxWidth: min(600, MediaQuery.of(context).size.width * 0.8),
                ),
                child: CitationsSection(
                  messageId: message.id,
                  sourceReferences: sourceReferences,
                ),
              ),
            if (!isStreaming)
              _buildAgentMessageActionsRow(
                context,
                messageText: text,
              ),
          ],
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

  Widget _buildUserMessageActionsRow(
    BuildContext context, {
    required String messageText,
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
          _ActionButton(
            tooltip: 'Copy message',
            icon: Icons.copy,
            onTap: () => _copyToClipboard(context, messageText),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentMessageActionsRow(
    BuildContext context, {
    required String messageText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        top: SoliplexSpacing.s1,
        left: SoliplexSpacing.s3,
      ),
      child: Row(
        spacing: SoliplexSpacing.s2,
        children: [
          _ActionButton(
            tooltip: 'Copy message',
            icon: Icons.copy,
            onTap: () => _copyToClipboard(context, messageText),
          ),
        ],
      ),
    );
  }

  Future<void> _openLink(String href, String? title) async {
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception catch (e, stackTrace) {
      Loggers.ui.error(
        'Failed to open link: $href',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _openImage(BuildContext context, String src, String? alt) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullscreenImageViewer(imageUrl: src, altText: alt),
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    void showSnackBar(String message) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
    }

    try {
      await Clipboard.setData(ClipboardData(text: text));
      showSnackBar('Copied to clipboard');
    } on PlatformException catch (e, stackTrace) {
      Loggers.ui
          .error('Clipboard copy failed', error: e, stackTrace: stackTrace);
      showSnackBar('Could not copy to clipboard');
    }
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

/// Collapsible section that displays the model's thinking/reasoning process.
class ThinkingSection extends StatefulWidget {
  const ThinkingSection({
    required this.thinkingText,
    required this.isStreaming,
    super.key,
  });

  final String thinkingText;
  final bool isStreaming;

  @override
  State<ThinkingSection> createState() => _ThinkingSectionState();
}

class _ThinkingSectionState extends State<ThinkingSection> {
  late bool _isExpanded;
  late bool _wasStreaming;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.thinkingText.isNotEmpty || widget.isStreaming;
    _wasStreaming = widget.isStreaming;
  }

  @override
  void didUpdateWidget(ThinkingSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-expand when streaming starts
    if (widget.isStreaming && !_wasStreaming) {
      setState(() {
        _isExpanded = true;
      });
    }
    // Auto-collapse when streaming ends
    else if (!widget.isStreaming && _wasStreaming) {
      setState(() {
        _isExpanded = false;
      });
    }

    _wasStreaming = widget.isStreaming;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soliplexTheme = SoliplexTheme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(soliplexTheme.radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (always visible)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(soliplexTheme.radii.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.psychology,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Thinking',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Content (expandable)
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SelectionArea(
                child: Text(
                  widget.thinkingText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.tooltip, required this.icon, this.onTap});

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Icon(
            icon,
            size: _iconSize,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
