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

/// Panel displaying HTTP traffic log for debugging.
class HttpInspectorPanel extends ConsumerWidget {
  const HttpInspectorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(httpLogProvider);
    final groups = groupHttpEvents(events);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < SoliplexBreakpoints.mobile;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(theme, groups.length, isCompact),
            const Divider(height: 1),
            Expanded(
              child: groups.isEmpty
                  ? _buildEmptyState(theme, isCompact)
                  : _buildList(context, groups, isCompact),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isCompact) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 16 : 24),
        child: Text(
          'No HTTP activity yet',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<HttpEventGroup> groups,
    bool isCompact,
  ) {
    return ListView.separated(
      reverse: true,
      padding: EdgeInsets.symmetric(vertical: isCompact ? 4 : 8),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final reversedIndex = groups.length - 1 - index;
        final group = groups[reversedIndex];
        return HttpEventTile(
          group: group,
          dense: isCompact,
          onTap: () => _showDetail(context, group),
        );
      },
    );
  }

  void _showDetail(BuildContext context, HttpEventGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DetailPage(group: group),
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    int requestCount,
    bool isCompact,
  ) {
    final titleStyle =
        isCompact ? theme.textTheme.titleSmall : theme.textTheme.titleMedium;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: isCompact ? 10 : 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Requests ($requestCount)', style: titleStyle),
          ),
          const _ClearButton(),
        ],
      ),
    );
  }
}

class _ClearButton extends ConsumerWidget {
  const _ClearButton();

  void _clear(WidgetRef ref) {
    ref.read(httpLogProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.delete_outline),
      onPressed: () => _clear(ref),
      tooltip: 'Clear log',
    );
  }
}

class _DetailPage extends StatelessWidget {
  const _DetailPage({required this.group});

  final HttpEventGroup group;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      config: ShellConfig(
        title: Text(group.pathWithQuery),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      body: RequestDetailView(group: group),
    );
  }
}
