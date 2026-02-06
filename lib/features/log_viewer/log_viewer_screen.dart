import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/logging/logging_provider.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/log_viewer/widgets/log_record_tile.dart';
import 'package:soliplex_frontend/shared/widgets/app_shell.dart';
import 'package:soliplex_frontend/shared/widgets/shell_config.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

/// In-app log viewer screen.
///
/// Displays log entries from [MemorySink] with level, logger, and text
/// filtering. Live-updates via stream subscriptions on [MemorySink.onRecord]
/// and [MemorySink.onClear].
class LogViewerScreen extends ConsumerStatefulWidget {
  const LogViewerScreen({super.key});

  @override
  ConsumerState<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends ConsumerState<LogViewerScreen> {
  /// Empty = all levels shown. Non-empty = only selected levels shown.
  var _selectedLevels = <LogLevel>{};

  /// Logger names to exclude from view. Default excludes 'HTTP' since it
  /// is noisy and has its own Network Inspector screen.
  var _excludedLoggers = const <String>{'HTTP'};

  String _searchQuery = '';

  /// Pre-computed lowercase search query to avoid repeated `toLowerCase`
  /// calls inside the filter predicate.
  String _lowerSearchQuery = '';

  /// Filtered records in oldest-first order. The ListView uses `reverse: true`
  /// so items are appended with O(1) `add()` and displayed newest-first.
  List<LogRecord> _filteredRecords = [];

  /// Cached set of distinct logger names from the sink buffer.
  /// Updated incrementally during flush and rebuilt during resync.
  var _availableLoggers = <String>{};

  StreamSubscription<LogRecord>? _recordSub;
  StreamSubscription<void>? _clearSub;

  /// Pending records buffered from the stream, flushed to UI every
  /// [kFlushInterval] to prevent per-event rebuilds during log bursts.
  final _pendingRecords = <LogRecord>[];
  Timer? _flushTimer;

  /// How often pending records are flushed to the UI.
  @visibleForTesting
  static const kFlushInterval = Duration(milliseconds: 100);

  late MemorySink _sink;

  @override
  void initState() {
    super.initState();
    _sink = ref.read(memorySinkProvider);
    _rebuildLoggerNames();
    _refilter();
    _recordSub = _sink.onRecord.listen(_onRecord);
    _clearSub = _sink.onClear.listen((_) => _onClear());
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    _recordSub?.cancel();
    _clearSub?.cancel();
    super.dispose();
  }

  /// Buffers incoming records and schedules a batched UI update.
  void _onRecord(LogRecord record) {
    _pendingRecords.add(record);
    _flushTimer ??= Timer(kFlushInterval, _flushPending);
  }

  /// Applies all buffered records to the UI in a single [setState].
  ///
  /// When [_filteredRecords] exceeds the sink's capacity, old records have
  /// been silently dropped from the ring buffer. A full resync sheds stale
  /// entries and prunes logger names that no longer have records.
  void _flushPending() {
    _flushTimer = null;
    if (!mounted || _pendingRecords.isEmpty) return;
    setState(() {
      for (final record in _pendingRecords) {
        _availableLoggers.add(record.loggerName);
        if (_matchesFilter(record)) {
          _filteredRecords.add(record);
        }
      }
      _pendingRecords.clear();
      if (_filteredRecords.length > _sink.maxRecords) {
        _refilter();
        _rebuildLoggerNames();
      }
    });
  }

  void _onClear() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pendingRecords.clear();
    setState(() {
      _filteredRecords = [];
      _availableLoggers = {};
    });
  }

  bool _matchesFilter(LogRecord record) {
    if (_selectedLevels.isNotEmpty && !_selectedLevels.contains(record.level)) {
      return false;
    }
    if (_excludedLoggers.contains(record.loggerName)) {
      return false;
    }
    if (_lowerSearchQuery.isNotEmpty &&
        !record.message.toLowerCase().contains(_lowerSearchQuery)) {
      return false;
    }
    return true;
  }

  /// Rebuilds [_filteredRecords] from the full sink buffer.
  void _refilter() {
    _filteredRecords = _sink.records.where(_matchesFilter).toList();
  }

  void _rebuildLoggerNames() {
    _availableLoggers = {
      for (final record in _sink.records) record.loggerName,
    };
  }

  void _clearLogs() {
    _sink.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      config: ShellConfig(
        title: Text('Logs (${_filteredRecords.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _filteredRecords.isEmpty ? null : _clearLogs,
            tooltip: 'Clear all logs',
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            selectedLevels: _selectedLevels,
            excludedLoggers: _excludedLoggers,
            searchQuery: _searchQuery,
            availableLoggers: _availableLoggers,
            onLevelsChanged: (levels) {
              setState(() {
                _selectedLevels = levels;
                _refilter();
              });
            },
            onExcludedLoggersChanged: (excluded) {
              setState(() {
                _excludedLoggers = excluded;
                _refilter();
              });
            },
            onSearchChanged: (query) {
              setState(() {
                _searchQuery = query;
                _lowerSearchQuery = query.toLowerCase();
                _refilter();
              });
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: _filteredRecords.isEmpty
                ? _buildEmptyState(context)
                : _buildList(),
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

  Widget _buildList() {
    return ListView.separated(
      // reverse: true renders newest (last in list) at the top, and allows
      // O(1) appends via List.add() instead of O(N) insert(0).
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: SoliplexSpacing.s2),
      itemCount: _filteredRecords.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) => LogRecordTile(record: _filteredRecords[index]),
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
