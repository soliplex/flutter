import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/logging/logging_provider.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/log_viewer/log_viewer_controller.dart';
import 'package:soliplex_frontend/features/log_viewer/widgets/log_record_tile.dart';
import 'package:soliplex_frontend/shared/widgets/app_shell.dart';
import 'package:soliplex_frontend/shared/widgets/shell_config.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

/// In-app log viewer screen.
///
/// Thin view that delegates all filter/buffer/stream logic to
/// [LogViewerController].
class LogViewerScreen extends ConsumerStatefulWidget {
  const LogViewerScreen({super.key});

  @override
  ConsumerState<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends ConsumerState<LogViewerScreen> {
  late final LogViewerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LogViewerController(
      sink: ref.read(memorySinkProvider),
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = _controller.filteredRecords;

    return AppShell(
      config: ShellConfig(
        title: Text('Logs (${records.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: records.isEmpty ? null : _controller.clearLogs,
            tooltip: 'Clear all logs',
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            selectedLevels: _controller.selectedLevels,
            excludedLoggers: _controller.excludedLoggers,
            searchQuery: _controller.searchQuery,
            availableLoggers: _controller.availableLoggers,
            onLevelsChanged: _controller.setSelectedLevels,
            onExcludedLoggersChanged: _controller.setExcludedLoggers,
            onSearchChanged: _controller.setSearchQuery,
          ),
          const Divider(height: 1),
          Expanded(
            child: records.isEmpty
                ? _buildEmptyState(context)
                : _buildList(records),
          ),
        ],
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
            Icons.article_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: SoliplexSpacing.s4),
          Text(
            'No log entries',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SoliplexSpacing.s2),
          Text(
            'Log entries will appear here as you use the app',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<LogRecord> records) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: SoliplexSpacing.s2),
      itemCount: records.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) =>
          LogRecordTile(record: records[records.length - 1 - index]),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedLevels,
    required this.excludedLoggers,
    required this.searchQuery,
    required this.availableLoggers,
    required this.onLevelsChanged,
    required this.onExcludedLoggersChanged,
    required this.onSearchChanged,
  });

  final Set<LogLevel> selectedLevels;
  final Set<String> excludedLoggers;
  final String searchQuery;
  final Set<String> availableLoggers;
  final ValueChanged<Set<LogLevel>> onLevelsChanged;
  final ValueChanged<Set<String>> onExcludedLoggersChanged;
  final ValueChanged<String> onSearchChanged;

  bool get _allLevelsSelected => selectedLevels.isEmpty;

  bool get _allLoggersSelected =>
      availableLoggers.isNotEmpty && excludedLoggers.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SoliplexSpacing.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: SoliplexSpacing.s1,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _allLevelsSelected,
                  onSelected: (_) => onLevelsChanged({}),
                ),
                for (final level in LogLevel.values)
                  FilterChip(
                    label: Text(level.label),
                    selected: selectedLevels.contains(level),
                    onSelected: (selected) {
                      final updated = Set<LogLevel>.from(selectedLevels);
                      if (selected) {
                        updated.add(level);
                      } else {
                        updated.remove(level);
                      }
                      onLevelsChanged(updated);
                    },
                  ),
              ],
            ),
          ),
          if (availableLoggers.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: SoliplexSpacing.s1,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _allLoggersSelected,
                    onSelected: (_) => onExcludedLoggersChanged({}),
                  ),
                  for (final logger in availableLoggers.toList()..sort())
                    FilterChip(
                      label: Text(logger),
                      selected: !excludedLoggers.contains(logger),
                      onSelected: (selected) {
                        final updated = Set<String>.from(excludedLoggers);
                        if (selected) {
                          updated.remove(logger);
                        } else {
                          updated.add(logger);
                        }
                        onExcludedLoggersChanged(updated);
                      },
                    ),
                ],
              ),
            ),
          const SizedBox(height: SoliplexSpacing.s1),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search logs...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: onSearchChanged,
          ),
        ],
      ),
    );
  }
}
