import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_client/soliplex_client.dart' hide State;

import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/documents_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
import 'package:soliplex_frontend/design/design.dart';
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
    final features = ref.watch(featuresProvider);

    final body = roomsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load room')),
      data: (rooms) {
        final room = rooms.where((r) => r.id == roomId).firstOrNull;
        if (room == null) {
          return const Center(child: Text('Room not found'));
        }
        return _RoomInfoBody(room: room, roomId: roomId);
      },
    );

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
      body: body,
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
    final clientTools = ref.watch(toolRegistryProvider).toolDefinitions;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (room.hasDescription)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              room.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        if (room.agent != null) _AgentCard(agent: room.agent!),
        _FeaturesCard(room: room, roomId: roomId),
        if (room.tools.isNotEmpty) _ToolsCard(tools: room.tools),
        if (room.mcpClientToolsets.isNotEmpty)
          _McpToolsetsCard(toolsets: room.mcpClientToolsets),
        if (clientTools.isNotEmpty) _ClientToolsCard(tools: clientTools),
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
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
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
          DefaultRoomAgent(
            :final providerType,
            :final retries,
            :final systemPrompt,
          ) =>
            [
              _InfoRow(label: 'Provider', value: providerType),
              _InfoRow(label: 'Retries', value: '$retries'),
              if (systemPrompt != null)
                _SystemPromptViewer(prompt: systemPrompt),
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
  bool _copied = false;

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
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  _copied ? Icons.check : Icons.copy,
                  size: 18,
                ),
                onPressed: _copied
                    ? null
                    : () {
                        Clipboard.setData(
                          ClipboardData(text: widget.prompt),
                        );
                        setState(() => _copied = true);
                        Future<void>.delayed(
                          const Duration(seconds: 2),
                          () {
                            if (mounted) setState(() => _copied = false);
                          },
                        );
                      },
                tooltip: 'Copy system prompt',
                iconSize: 18,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final promptStyle = theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontSize: 14,
              );
              const containerPadding = 16.0; // 8 left + 8 right
              final overflows = !_expanded &&
                  (TextPainter(
                    text: TextSpan(
                      text: widget.prompt,
                      style: promptStyle,
                    ),
                    maxLines: _collapsedMaxLines,
                    textDirection: TextDirection.ltr,
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout(
                          maxWidth: constraints.maxWidth - containerPadding,
                        ))
                      .didExceedMaxLines;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        style: promptStyle,
                      ),
                    ),
                  ),
                  if (overflows)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _expanded = true),
                        child: const Text('Show more'),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard({required this.room, required this.roomId});
  final Room room;
  final String roomId;

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
          label: 'Allow MCP',
          value: room.allowMcp ? 'Yes' : 'No',
        ),
        if (room.allowMcp) _McpTokenRow(roomId: roomId),
        if (room.aguiFeatureNames.isNotEmpty)
          _InfoRow(
            label: 'AG-UI Features',
            value: room.aguiFeatureNames.join(', '),
          ),
      ],
    );
  }
}

class _McpTokenRow extends ConsumerStatefulWidget {
  const _McpTokenRow({required this.roomId});
  final String roomId;

  @override
  ConsumerState<_McpTokenRow> createState() => _McpTokenRowState();
}

class _McpTokenRowState extends ConsumerState<_McpTokenRow> {
  Future<String>? _tokenFuture;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _tokenFuture = ref.read(apiProvider).getMcpToken(widget.roomId);
  }

  void _copyToken(String token) {
    Clipboard.setData(ClipboardData(text: token));
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _tokenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry token'),
              onPressed: () => setState(() {
                _tokenFuture = ref.read(apiProvider).getMcpToken(widget.roomId);
              }),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final token = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: OutlinedButton.icon(
            icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
            label: Text(_copied ? 'Copied' : 'Copy Token'),
            onPressed: _copied ? null : () => _copyToken(token),
          ),
        );
      },
    );
  }
}

class _ExpandableTile extends StatelessWidget {
  const _ExpandableTile({
    required this.name,
    required this.expanded,
    required this.onToggle,
    this.content,
  });

  final String name;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget? content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasContent = content != null;

    final nameRow = Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (hasContent)
          Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
      ],
    );

    return GestureDetector(
      onTap: hasContent ? onToggle : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            nameRow,
            if (expanded && hasContent)
              Padding(
                padding: const EdgeInsets.only(top: SoliplexSpacing.s1),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(SoliplexSpacing.s2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(SoliplexSpacing.s2),
                  ),
                  child: content,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolsCard extends StatefulWidget {
  const _ToolsCard({required this.tools});
  final Map<String, RoomTool> tools;

  @override
  State<_ToolsCard> createState() => _ToolsCardState();
}

class _ToolsCardState extends State<_ToolsCard> {
  final _expandedNames = <String>{};

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'TOOLS (${widget.tools.length})',
      children: [
        for (final entry in widget.tools.entries)
          _buildToolTile(entry.key, entry.value),
      ],
    );
  }

  Widget _buildToolTile(String name, RoomTool tool) {
    return _ExpandableTile(
      name: name,
      expanded: _expandedNames.contains(name),
      onToggle: () => setState(() {
        if (_expandedNames.contains(name)) {
          _expandedNames.remove(name);
        } else {
          _expandedNames.add(name);
        }
      }),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: 'Kind', value: tool.kind),
          if (tool.description.isNotEmpty)
            _InfoRow(label: 'Description', value: tool.description),
          if (tool.allowMcp) const _InfoRow(label: 'Allow MCP', value: 'Yes'),
          if (tool.toolRequires.isNotEmpty)
            _InfoRow(label: 'Requires', value: tool.toolRequires),
          if (tool.aguiFeatureNames.isNotEmpty)
            _InfoRow(
              label: 'AG-UI Features',
              value: tool.aguiFeatureNames.join(', '),
            ),
        ],
      ),
    );
  }
}

class _McpToolsetsCard extends StatefulWidget {
  const _McpToolsetsCard({required this.toolsets});
  final Map<String, McpClientToolset> toolsets;

  @override
  State<_McpToolsetsCard> createState() => _McpToolsetsCardState();
}

class _McpToolsetsCardState extends State<_McpToolsetsCard> {
  final _expandedNames = <String>{};

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'MCP CLIENT TOOLSETS (${widget.toolsets.length})',
      children: [
        for (final entry in widget.toolsets.entries)
          _buildToolsetTile(entry.key, entry.value),
      ],
    );
  }

  Widget _buildToolsetTile(String name, McpClientToolset toolset) {
    return _ExpandableTile(
      name: name,
      expanded: _expandedNames.contains(name),
      onToggle: () => setState(() {
        if (_expandedNames.contains(name)) {
          _expandedNames.remove(name);
        } else {
          _expandedNames.add(name);
        }
      }),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: 'Kind', value: toolset.kind),
          if (toolset.allowedTools != null)
            _InfoRow(
              label: 'Allowed Tools',
              value: toolset.allowedTools!.join(', '),
            ),
        ],
      ),
    );
  }
}

class _ClientToolsCard extends StatefulWidget {
  const _ClientToolsCard({required this.tools});
  final List<Tool> tools;

  @override
  State<_ClientToolsCard> createState() => _ClientToolsCardState();
}

class _ClientToolsCardState extends State<_ClientToolsCard> {
  final _expandedNames = <String>{};

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'CLIENT TOOLS (${widget.tools.length})',
      children: [
        for (final tool in widget.tools) _buildToolTile(tool),
      ],
    );
  }

  Widget _buildToolTile(Tool tool) {
    return _ExpandableTile(
      name: tool.name,
      expanded: _expandedNames.contains(tool.name),
      onToggle: () => setState(() {
        if (_expandedNames.contains(tool.name)) {
          _expandedNames.remove(tool.name);
        } else {
          _expandedNames.add(tool.name);
        }
      }),
      content: tool.description.isNotEmpty
          ? Text(
              tool.description,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : null,
    );
  }
}

class _DocumentsCard extends StatefulWidget {
  const _DocumentsCard({
    required this.documentsAsync,
    required this.onRetry,
  });

  final AsyncValue<List<RagDocument>> documentsAsync;
  final VoidCallback onRetry;

  @override
  State<_DocumentsCard> createState() => _DocumentsCardState();
}

class _DocumentsCardState extends State<_DocumentsCard> {
  static const _maxHeight = 600.0;
  static const _shrinkWrapThreshold = 15;

  final _expandedIds = <String>{};
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RagDocument> _filterDocs(List<RagDocument> docs) {
    if (_searchQuery.isEmpty) return docs;
    final query = _searchQuery.toLowerCase();
    return docs
        .where(
          (d) =>
              d.title.toLowerCase().contains(query) ||
              d.uri.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (title, children) = widget.documentsAsync.when(
      data: (docs) {
        if (docs.isEmpty) {
          return (
            'DOCUMENTS (0)',
            [
              Text(
                'No documents in this room.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }
        final filtered = _filterDocs(docs);
        final t = _searchQuery.isEmpty
            ? 'DOCUMENTS (${docs.length})'
            : 'DOCUMENTS (${filtered.length} / ${docs.length})';
        return (
          t,
          <Widget>[
            if (docs.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search documents...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _maxHeight),
              child: ListView.builder(
                shrinkWrap: filtered.length <= _shrinkWrapThreshold,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final doc = filtered[index];
                  final expanded = _expandedIds.contains(doc.id);
                  return _buildDocTile(doc, expanded, theme);
                },
              ),
            ),
          ],
        );
      },
      loading: () => (
        'DOCUMENTS',
        <Widget>[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (error, _) => (
        'DOCUMENTS',
        <Widget>[
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 18,
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
                onPressed: widget.onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      ),
    );

    return _SectionCard(
      title: title,
      children: children,
    );
  }

  Widget _buildDocTile(
    RagDocument doc,
    bool expanded,
    ThemeData theme,
  ) {
    return GestureDetector(
      onTap: () => setState(() {
        if (expanded) {
          _expandedIds.remove(doc.id);
        } else {
          _expandedIds.add(doc.id);
        }
      }),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(getFileTypeIcon(doc.title), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    doc.title,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            if (expanded) _buildDocMetadata(doc),
          ],
        ),
      ),
    );
  }

  Widget _buildDocMetadata(RagDocument doc) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.bodySmall;

    final dateFields = <(String, String)>[];
    if (doc.createdAt != null) {
      dateFields.add(('created_at', _formatDateTime(doc.createdAt!)));
    }
    if (doc.updatedAt != null) {
      dateFields.add(('updated_at', _formatDateTime(doc.updatedAt!)));
    }

    return Padding(
      padding: const EdgeInsets.only(top: SoliplexSpacing.s1),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SoliplexSpacing.s2),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(SoliplexSpacing.s2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('id', style: labelStyle),
            const SizedBox(height: 2),
            SelectableText(
              doc.id,
              style: valueStyle?.copyWith(fontFamily: 'monospace'),
            ),
            if (doc.uri.isNotEmpty || dateFields.isNotEmpty)
              const SizedBox(height: SoliplexSpacing.s2),
            if (doc.uri.isNotEmpty) ...[
              Text('uri', style: labelStyle),
              const SizedBox(height: 2),
              SelectableText(
                doc.uri,
                style: valueStyle?.copyWith(fontFamily: 'monospace'),
              ),
              if (dateFields.isNotEmpty)
                const SizedBox(height: SoliplexSpacing.s2),
            ],
            if (dateFields.isNotEmpty)
              Wrap(
                spacing: SoliplexSpacing.s4,
                runSpacing: SoliplexSpacing.s2,
                children: [
                  for (final (label, value) in dateFields)
                    SizedBox(
                      width: 160,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: labelStyle),
                          const SizedBox(height: 2),
                          SelectableText(
                            value,
                            style: valueStyle,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            if (doc.metadata.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    textStyle: theme.textTheme.labelSmall,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _MetadataDialog(
                      title: doc.title,
                      metadata: doc.metadata,
                    ),
                  ),
                  child: const Text('Show metadata'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _MetadataDialog extends StatelessWidget {
  const _MetadataDialog({
    required this.title,
    required this.metadata,
  });

  final String title;
  final Map<String, dynamic> metadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entries = metadata.entries.toList();

    return AlertDialog(
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in entries) ...[
                SizedBox(
                  width: double.infinity,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(SoliplexSpacing.s3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            entry.value.toString(),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (entry.key != entries.last.key)
                  const SizedBox(height: SoliplexSpacing.s2),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
