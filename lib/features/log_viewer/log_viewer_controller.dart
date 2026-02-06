import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

/// Manages filter state, stream buffering, and record filtering for the
/// log viewer.
///
/// Extracted from `LogViewerScreen` to keep the view a humble widget that
/// only builds UI. All logging-aware logic lives here.
class LogViewerController {
  LogViewerController({
    required MemorySink sink,
    required VoidCallback onChanged,
  })  : _sink = sink,
        _onChanged = onChanged {
    _rebuildLoggerNames();
    _refilter();
    _recordSub = _sink.onRecord.listen(_onRecord);
    _clearSub = _sink.onClear.listen((_) => _onClear());
  }

  final MemorySink _sink;
  final VoidCallback _onChanged;

  /// How often pending records are flushed to the UI.
  @visibleForTesting
  static const kFlushInterval = Duration(milliseconds: 100);

  // ---------------------------------------------------------------------------
  // Filter state
  // ---------------------------------------------------------------------------

  /// Empty = all levels shown. Non-empty = only selected levels shown.
  var _selectedLevels = <LogLevel>{};
  Set<LogLevel> get selectedLevels => _selectedLevels;

  /// Logger names to exclude from view. Default excludes HTTP since it
  /// is noisy and has its own Network Inspector screen.
  var _excludedLoggers = <String>{Loggers.http.name};
  Set<String> get excludedLoggers => _excludedLoggers;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  /// Pre-computed lowercase search query to avoid repeated `toLowerCase`
  /// calls inside the filter predicate.
  String _lowerSearchQuery = '';

  // ---------------------------------------------------------------------------
  // Record state
  // ---------------------------------------------------------------------------

  /// Filtered records in oldest-first order. The ListView uses `reverse: true`
  /// so items are appended with O(1) `add()` and displayed newest-first.
  List<LogRecord> _filteredRecords = [];
  List<LogRecord> get filteredRecords => _filteredRecords;

  /// Cached set of distinct logger names from the sink buffer.
  var _availableLoggers = <String>{};
  Set<String> get availableLoggers => _availableLoggers;

  // ---------------------------------------------------------------------------
  // Stream / buffer internals
  // ---------------------------------------------------------------------------

  StreamSubscription<LogRecord>? _recordSub;
  StreamSubscription<void>? _clearSub;

  /// Pending records buffered from the stream, flushed to UI every
  /// [kFlushInterval] to prevent per-event rebuilds during log bursts.
  final _pendingRecords = <LogRecord>[];
  Timer? _flushTimer;

  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  void setSelectedLevels(Set<LogLevel> levels) {
    _selectedLevels = levels;
    _refilter();
    _onChanged();
  }

  void setExcludedLoggers(Set<String> excluded) {
    _excludedLoggers = excluded;
    _refilter();
    _onChanged();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _lowerSearchQuery = query.toLowerCase();
    _refilter();
    _onChanged();
  }

  void clearLogs() {
    _sink.clear();
  }

  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _recordSub?.cancel();
    _clearSub?.cancel();
  }

  // ---------------------------------------------------------------------------
  // Internal logic
  // ---------------------------------------------------------------------------

  void _onRecord(LogRecord record) {
    _pendingRecords.add(record);
    _flushTimer ??= Timer(kFlushInterval, _flushPending);
  }

  /// Applies all buffered records to the UI in a single notification.
  ///
  /// When [_filteredRecords] exceeds the sink's capacity, old records have
  /// been silently dropped from the ring buffer. A full resync sheds stale
  /// entries and prunes logger names that no longer have records.
  void _flushPending() {
    _flushTimer = null;
    if (_disposed || _pendingRecords.isEmpty) return;

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

    _onChanged();
  }

  void _onClear() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pendingRecords.clear();
    _filteredRecords = [];
    _availableLoggers = {};
    _onChanged();
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
}
