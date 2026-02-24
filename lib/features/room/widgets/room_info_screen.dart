import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_client/soliplex_client.dart' hide State;

import 'package:soliplex_frontend/core/providers/documents_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
import 'package:soliplex_frontend/shared/utils/file_type_icons.dart';
import 'package:soliplex_frontend/shared/widgets/app_shell.dart';
import 'package:soliplex_frontend/shared/widgets/shell_config.dart';

/// Screen displaying room configuration and documents.
class RoomInfoScreen extends ConsumerWidget {
  const RoomInfoScreen({required this.roomId, super.key});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsProvider);
    final room = roomsAsync.whenOrNull(
      data: (rooms) => rooms.where((r) => r.id == roomId).firstOrNull,
    );
    final features = ref.watch(featuresProvider);

    return AppShell(
      config: ShellConfig(
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back),
          tooltip: 'Back to room',
          onPressed: () => context.go('/rooms/$roomId'),
        ),
        title: const Text('Room Information'),
        actions: [
          if (features.enableSettings)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => context.push('/settings'),
              tooltip: 'Open settings',
            ),
        ],
      ),
      body: room == null
          ? const Center(child: CircularProgressIndicator())
          : _RoomInfoBody(room: room, roomId: roomId),
    );
  }
}

class _RoomInfoBody extends ConsumerWidget {
  const _RoomInfoBody({required this.room, required this.roomId});

  final Room room;
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(documentsProvider(roomId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (room.hasDescription)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              room.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        if (room.agent != null) _AgentCard(agent: room.agent!),
        _FeaturesCard(room: room),
        if (room.tools.isNotEmpty) _ToolsCard(tools: room.tools),
        if (room.mcpClientToolsets.isNotEmpty)
          _McpToolsetsCard(toolsets: room.mcpClientToolsets),
        _DocumentsCard(
          documentsAsync: documentsAsync,
          onRetry: () => ref.read(documentsProvider(roomId).notifier).retry(),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent});
  final RoomAgent agent;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'AGENT',
      children: [
        _InfoRow(label: 'Model', value: agent.displayModelName),
        ...switch (agent) {
          DefaultRoomAgent(:final providerType) => [
              _InfoRow(label: 'Provider', value: providerType),
              _InfoRow(
                label: 'Retries',
                value: '${(agent as DefaultRoomAgent).retries}',
              ),
              if ((agent as DefaultRoomAgent).systemPrompt != null)
                _SystemPromptViewer(
                  prompt: (agent as DefaultRoomAgent).systemPrompt!,
                ),
            ],
          FactoryRoomAgent(:final extraConfig) when extraConfig.isNotEmpty => [
              _InfoRow(
                label: 'Extra Config',
                value: extraConfig.toString(),
              ),
            ],
          _ => <Widget>[],
        },
        if (agent.aguiFeatureNames.isNotEmpty)
          _InfoRow(
            label: 'AG-UI Features',
            value: agent.aguiFeatureNames.join(', '),
          ),
      ],
    );
  }
}

class _SystemPromptViewer extends StatefulWidget {
  const _SystemPromptViewer({required this.prompt});
  final String prompt;

  @override
  State<_SystemPromptViewer> createState() => _SystemPromptViewerState();
}

class _SystemPromptViewerState extends State<_SystemPromptViewer> {
  bool _expanded = false;

  static const _collapsedMaxLines = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'System Prompt',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: widget.prompt),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('System prompt copied'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                tooltip: 'Copy system prompt',
                iconSize: 16,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                widget.prompt,
                maxLines: _expanded ? null : _collapsedMaxLines,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
          if (!_expanded &&
              widget.prompt.split('\n').length > _collapsedMaxLines)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _expanded = true),
                child: const Text('Show more'),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'FEATURES',
      children: [
        _InfoRow(
          label: 'Attachments',
          value: room.enableAttachments ? 'Enabled' : 'Disabled',
        ),
        _InfoRow(
          label: 'MCP Allowed',
          value: room.allowMcp ? 'Yes' : 'No',
        ),
        if (room.aguiFeatureNames.isNotEmpty)
          _InfoRow(
            label: 'AG-UI Features',
            value: room.aguiFeatureNames.join(', '),
          ),
      ],
    );
  }
}

class _ToolsCard extends StatelessWidget {
  const _ToolsCard({required this.tools});
  final Map<String, RoomTool> tools;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _SectionCard(
      title: 'TOOLS (${tools.length})',
      children: [
        for (final entry in tools.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      entry.value.isRagTool
                          ? Icons.search
                          : Icons.build_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.key,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '[${entry.value.kind}]',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (entry.value.allowMcp) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.hub_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
                if (entry.value.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(
                      entry.value.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _McpToolsetsCard extends StatelessWidget {
  const _McpToolsetsCard({required this.toolsets});
  final Map<String, McpClientToolset> toolsets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _SectionCard(
      title: 'MCP CLIENT TOOLSETS (${toolsets.length})',
      children: [
        for (final entry in toolsets.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.hub_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.key,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '[${entry.value.kind}]',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (entry.value.allowedTools != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(
                      'Allowed: '
                      '${entry.value.allowedTools!.join(', ')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard({
    required this.documentsAsync,
    required this.onRetry,
  });

  static const _maxHeight = 300.0;

  final AsyncValue<List<RagDocument>> documentsAsync;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = documentsAsync.when(
      data: (docs) => 'DOCUMENTS (${docs.length})',
      loading: () => 'DOCUMENTS',
      error: (_, __) => 'DOCUMENTS',
    );

    return _SectionCard(
      title: title,
      children: [
        documentsAsync.when(
          data: (docs) {
            if (docs.isEmpty) {
              return Text(
                'No documents in this room.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _maxHeight),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(getFileTypeIcon(doc.title), size: 20),
                    title: Text(
                      doc.title,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 16,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Failed to load documents',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
