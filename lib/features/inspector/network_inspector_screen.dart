import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:soliplex_frontend/core/providers/http_log_provider.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/inspector/models/http_event_group.dart';
import 'package:soliplex_frontend/features/inspector/models/http_event_grouper.dart';
import 'package:soliplex_frontend/features/inspector/widgets/http_event_tile.dart';
import 'package:soliplex_frontend/features/inspector/widgets/request_detail_view.dart';
import 'package:soliplex_frontend/shared/widgets/app_shell.dart';
import 'package:soliplex_frontend/shared/widgets/shell_config.dart';

/// Full-screen network inspector for debugging HTTP traffic.
///
/// On wide screens, shows a master-detail layout with list on the left
/// and detail view on the right. On narrow screens, tapping a request
/// navigates to a detail page.
class NetworkInspectorScreen extends ConsumerStatefulWidget {
  const NetworkInspectorScreen({super.key});

  @override
  ConsumerState<NetworkInspectorScreen> createState() =>
      _NetworkInspectorScreenState();
}

class _NetworkInspectorScreenState
    extends ConsumerState<NetworkInspectorScreen> {
  String? _selectedRequestId;

  void _clearRequests() {
    ref.read(httpLogProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(httpLogProvider);
    final groups = groupHttpEvents(events);
    // Most recent first
    final sortedGroups = groups.reversed.toList();

    return AppShell(
      config: ShellConfig(
        leading: [
          IconButton(
            icon: Icon(Icons.adaptive.arrow_back),
            onPressed: () => context.pop(),
            tooltip: 'Back',
          ),
        ],
        title: Text('Requests (${sortedGroups.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: sortedGroups.isEmpty ? null : _clearRequests,
            tooltip: 'Clear all requests',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= SoliplexBreakpoints.tablet;

          if (sortedGroups.isEmpty) {
            return _buildEmptyState(context);
          }

          if (isWide) {
            return _buildMasterDetailLayout(context, sortedGroups);
          }

          return _buildListLayout(context, sortedGroups);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.http,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: SoliplexSpacing.s4),
          Text(
            'No HTTP requests yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SoliplexSpacing.s2),
          Text(
            'Requests will appear here as you use the app',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListLayout(BuildContext context, List<HttpEventGroup> groups) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: SoliplexSpacing.s2),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final group = groups[index];
        return InkWell(
          onTap: () => _navigateToDetail(context, group),
          child: HttpEventTile(group: group),
        );
      },
    );
  }

  Widget _buildMasterDetailLayout(
    BuildContext context,
    List<HttpEventGroup> groups,
  ) {
    final theme = Theme.of(context);
    final selectedGroup = _selectedRequestId != null
        ? groups.where((g) => g.requestId == _selectedRequestId).firstOrNull
        : null;

    // Auto-select first if nothing selected
    final effectiveGroup = selectedGroup ?? groups.firstOrNull;
    final effectiveId = effectiveGroup?.requestId;

    return Row(
      children: [
        SizedBox(
          width: 360,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: SoliplexSpacing.s2),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final group = groups[index];
                final isSelected = group.requestId == effectiveId;
                return _SelectableEventTile(
                  group: group,
                  isSelected: isSelected,
                  onTap: () => setState(() {
                    _selectedRequestId = group.requestId;
                  }),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: effectiveGroup != null
              ? RequestDetailView(group: effectiveGroup)
              : _buildNoSelectionState(context),
        ),
      ],
    );
  }

  Widget _buildNoSelectionState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        'Select a request to view details',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, HttpEventGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _RequestDetailPage(group: group),
      ),
    );
  }
}

class _SelectableEventTile extends StatelessWidget {
  const _SelectableEventTile({
    required this.group,
    required this.isSelected,
    required this.onTap,
  });

  final HttpEventGroup group;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? colorScheme.primaryContainer : null,
        child: HttpEventTile(group: group, isSelected: isSelected),
      ),
    );
  }
}

/// Detail page for narrow screen navigation.
class _RequestDetailPage extends StatelessWidget {
  const _RequestDetailPage({required this.group});

  final HttpEventGroup group;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      config: ShellConfig(
        leading: [
          IconButton(
            icon: Icon(Icons.adaptive.arrow_back),
            onPressed: () => context.pop(),
            tooltip: 'Back',
          ),
        ],
        title: Text(group.pathWithQuery),
      ),
      body: RequestDetailView(group: group),
    );
  }
}
