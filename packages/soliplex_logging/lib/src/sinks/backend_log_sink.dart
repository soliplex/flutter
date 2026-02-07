import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:soliplex_logging/src/log_level.dart';
import 'package:soliplex_logging/src/log_record.dart';
import 'package:soliplex_logging/src/log_sink.dart';
import 'package:soliplex_logging/src/sinks/disk_queue.dart';
import 'package:soliplex_logging/src/sinks/memory_sink.dart';

/// Maximum record size in bytes before truncation (64 KB).
const int _maxRecordBytes = 64 * 1024;

/// Default maximum batch payload size in bytes (900 KB).
const int _defaultMaxBatchBytes = 900 * 1024;

/// Callback for error reporting from [BackendLogSink].
typedef SinkErrorCallback = void Function(String message, Object? error);

/// Log sink that persists records to disk and periodically POSTs them
/// as JSON to the Soliplex backend.
///
/// Records are always written to [DiskQueue] first, regardless of auth
/// state. Pre-login logs buffer on disk and ship together once
/// [jwtProvider] returns a non-null token.
class BackendLogSink implements LogSink {
  /// Creates a backend log sink.
  BackendLogSink({
    required this.endpoint,
    required http.Client client,
    required this.installId,
    required this.sessionId,
    required DiskQueue diskQueue,
    this.userId,
    this.memorySink,
    this.resourceAttributes = const {},
    this.maxBatchBytes = _defaultMaxBatchBytes,
    this.batchSize = 100,
    Duration flushInterval = const Duration(seconds: 30),
    this.networkChecker,
    this.jwtProvider,
    this.flushGate,
    this.maxFlushHoldDuration = const Duration(minutes: 5),
    this.onError,
  })  : _client = client,
        _diskQueue = diskQueue {
    _timer = Timer.periodic(flushInterval, (_) => flush());
  }

  /// Backend endpoint URL.
  final String endpoint;

  /// Per-install UUID.
  final String installId;

  /// Session UUID (new each app start).
  final String sessionId;

  /// Current user ID (null before auth).
  String? userId;

  /// Current active run thread ID (null when idle).
  String? threadId;

  /// Current active run ID (null when idle).
  String? runId;

  /// Optional memory sink for breadcrumb retrieval on error/fatal.
  final MemorySink? memorySink;

  /// Resource attributes for the payload envelope.
  final Map<String, Object> resourceAttributes;

  /// Maximum batch payload size in bytes.
  final int maxBatchBytes;

  /// Maximum records per batch.
  final int batchSize;

  /// Returns `true` if the device has network connectivity.
  final bool Function()? networkChecker;

  /// Returns the current JWT or null if not yet authenticated.
  final String? Function()? jwtProvider;

  /// Returns `true` when flushing is allowed.
  ///
  /// When non-null and returning `false`, periodic flushes are held until
  /// the gate opens or [maxFlushHoldDuration] elapses (safety valve).
  /// `flush(force: true)` bypasses this gate entirely.
  final bool Function()? flushGate;

  /// Maximum time to hold flushes when [flushGate] returns `false`.
  final Duration maxFlushHoldDuration;

  /// Callback for error reporting.
  final SinkErrorCallback? onError;

  final http.Client _client;
  final DiskQueue _diskQueue;
  late final Timer _timer;

  final List<Future<void>> _pendingWrites = [];

  bool _closed = false;
  bool _disabled = false;
  DateTime? _gatedSince;
  int _retryCount = 0;
  int _consecutiveFailures = 0;
  String? _lastJwt;

  /// Backoff state — exposed for testing.
  @visibleForTesting
  DateTime? backoffUntil;

  @override
  void write(LogRecord record) {
    if (_closed) return;

    final json = _recordToJson(record);

    if (record.level >= LogLevel.error && memorySink != null) {
      json['breadcrumbs'] = _collectBreadcrumbs();
    }

    final truncated = _truncateRecord(json);

    if (record.level == LogLevel.fatal) {
      _diskQueue.appendSync(truncated);
    } else {
      final future = _diskQueue.append(truncated);
      _pendingWrites.add(future);
      unawaited(future.whenComplete(() => _pendingWrites.remove(future)));
    }

    if (record.level >= LogLevel.error) {
      unawaited(flush(force: true));
    }
  }

  @override
  Future<void> flush({bool force = false}) async {
    if (_closed) return;

    // Wait for any pending async writes to complete.
    if (_pendingWrites.isNotEmpty) {
      await Future.wait(List.of(_pendingWrites));
    }

    // Check JWT availability (pre-auth buffering).
    final jwt = jwtProvider?.call();
    if (jwtProvider != null && jwt == null) return;

    // Re-enable if we got a new JWT after auth failure.
    if (_disabled && jwt != null && jwt != _lastJwt) {
      _disabled = false;
      _retryCount = 0;
      _consecutiveFailures = 0;
      backoffUntil = null;
    }
    _lastJwt = jwt;

    if (_disabled) return;

    // Respect network check.
    if (networkChecker != null && !networkChecker!()) return;

    // Respect backoff timer.
    if (backoffUntil != null && DateTime.now().isBefore(backoffUntil!)) {
      return;
    }

    // Respect flush gate (e.g., active run in progress).
    if (!force && flushGate != null && !flushGate!()) {
      _gatedSince ??= DateTime.now();
      if (DateTime.now().difference(_gatedSince!) < maxFlushHoldDuration) {
        return;
      }
      // Safety valve triggered — proceed to flush.
    }
    if (flushGate == null || flushGate!()) {
      _gatedSince = null;
    }

    final records = await _diskQueue.drain(batchSize);
    if (records.isEmpty) return;

    // Apply byte-based cap.
    final batch = _capByBytes(records);
    if (batch.isEmpty) return;

    final payload = jsonEncode({
      'logs': batch,
      'resource': resourceAttributes,
    });

    try {
      final response = await _client.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          if (jwt != null && jwt.isNotEmpty) 'Authorization': 'Bearer $jwt',
        },
        body: payload,
      );

      if (response.statusCode == 200) {
        await _diskQueue.confirm(batch.length);
        _retryCount = 0;
        _consecutiveFailures = 0;
        backoffUntil = null;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _disabled = true;
        onError?.call(
          'Auth failure (${response.statusCode}), disabling export',
          null,
        );
      } else if (response.statusCode == 404) {
        _disabled = true;
        onError?.call(
          'Endpoint not found (404), disabling export',
          null,
        );
      } else {
        // 429, 5xx — retry with backoff.
        await _handleRetryableError(batch.length);
      }
    } on Object catch (e) {
      // Network error — retry with backoff.
      await _handleRetryableError(batch.length);
      developer.log('Flush failed: $e', name: 'BackendLogSink');
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _timer.cancel();
    await flush(force: true);
    _closed = true;
    await _diskQueue.close();
  }

  Future<void> _handleRetryableError(int batchLength) async {
    _consecutiveFailures++;
    _retryCount++;

    // Poison pill: discard batch after 3 consecutive failures.
    if (_consecutiveFailures >= 3) {
      await _diskQueue.confirm(batchLength);
      _consecutiveFailures = 0;
      onError?.call(
        'Batch discarded after 3 consecutive failures (poison pill)',
        null,
      );
      return;
    }

    // Exponential backoff: 1s, 2s, 4s, ... max 60s.
    final seconds = min(pow(2, _retryCount - 1).toInt(), 60);
    backoffUntil = DateTime.now().add(Duration(seconds: seconds));
  }

  Map<String, Object?> _recordToJson(LogRecord record) {
    return {
      'timestamp': record.timestamp.toUtc().toIso8601String(),
      'level': record.level.name,
      'logger': record.loggerName,
      'message': record.message,
      'attributes': _safeAttributes(record.attributes),
      'error': record.error?.toString(),
      'stackTrace': record.stackTrace?.toString(),
      'spanId': record.spanId,
      'traceId': record.traceId,
      'installId': installId,
      'sessionId': sessionId,
      'userId': userId,
      'activeRun':
          threadId != null ? {'threadId': threadId, 'runId': runId} : null,
    };
  }

  /// Coerces non-JSON-primitive attribute values to String.
  Map<String, Object?> _safeAttributes(Map<String, Object> attributes) {
    if (attributes.isEmpty) return const {};
    final result = <String, Object?>{};
    for (final entry in attributes.entries) {
      result[entry.key] = _coerceValue(entry.value);
    }
    return result;
  }

  Object? _coerceValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is List) {
      return value.map(_coerceValue).toList();
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _coerceValue(v)));
    }
    return value.toString();
  }

  /// Truncates record fields to stay under the 64 KB limit.
  ///
  /// Truncation order: message, attributes, stackTrace, error.
  Map<String, Object?> _truncateRecord(Map<String, Object?> json) {
    final encoded = jsonEncode(json);
    if (encoded.length <= _maxRecordBytes) return json;

    final result = Map<String, Object?>.of(json);

    // Truncate in priority order.
    for (final key in const ['message', 'stackTrace', 'error']) {
      final value = result[key];
      if (value is String && value.length > 1024) {
        result[key] = _utf8SafeTruncate(value, 1024);
      }
      if (jsonEncode(result).length <= _maxRecordBytes) return result;
    }

    // Truncate attributes if still too large.
    if (result['attributes'] is Map) {
      result['attributes'] = const <String, Object?>{};
    }

    return result;
  }

  /// Truncates a string at a UTF-8 safe boundary.
  String _utf8SafeTruncate(String input, int maxBytes) {
    final encoded = utf8.encode(input);
    if (encoded.length <= maxBytes) return input;

    // Find the last valid UTF-8 character boundary.
    var end = maxBytes;
    while (end > 0 && (encoded[end] & 0xC0) == 0x80) {
      end--;
    }
    return '${utf8.decode(encoded.sublist(0, end))}…[truncated]';
  }

  /// Reads the last 20 records from [memorySink] as breadcrumbs.
  List<Map<String, Object?>> _collectBreadcrumbs() {
    final records = memorySink!.records;
    final start = records.length > 20 ? records.length - 20 : 0;
    return [
      for (var i = start; i < records.length; i++)
        _breadcrumbFromRecord(records[i]),
    ];
  }

  Map<String, Object?> _breadcrumbFromRecord(LogRecord record) {
    return {
      'timestamp': record.timestamp.toUtc().toIso8601String(),
      'level': record.level.name,
      'logger': record.loggerName,
      'message': record.message,
      'category': deriveBreadcrumbCategory(record),
    };
  }

  /// Caps records by byte size.
  List<Map<String, Object?>> _capByBytes(List<Map<String, Object?>> records) {
    final result = <Map<String, Object?>>[];
    var totalBytes = 0;
    // Account for envelope overhead: {"logs":[],"resource":{...}}
    final envelopeOverhead =
        jsonEncode({'logs': <Object>[], 'resource': resourceAttributes}).length;
    totalBytes += envelopeOverhead;

    for (final record in records) {
      final recordBytes = jsonEncode(record).length;
      if (totalBytes + recordBytes > maxBatchBytes && result.isNotEmpty) {
        break;
      }
      result.add(record);
      totalBytes += recordBytes;
    }
    return result;
  }
}

/// Logger name prefixes that map to breadcrumb categories.
const _loggerCategoryPrefixes = {
  'Router': 'ui',
  'Navigation': 'ui',
  'UI': 'ui',
  'Http': 'network',
  'Network': 'network',
  'Connectivity': 'network',
  'Lifecycle': 'system',
  'Permission': 'system',
  'Auth': 'user',
  'Login': 'user',
  'User': 'user',
};

/// Derives a breadcrumb category from a [LogRecord].
///
/// If the record has an explicit `breadcrumb_category` attribute, that
/// value is used. Otherwise, the category is inferred from the
/// [LogRecord.loggerName] prefix (e.g. `Router.Home` → `ui`).
/// Falls back to `system` if no match is found.
String deriveBreadcrumbCategory(LogRecord record) {
  final explicit = record.attributes['breadcrumb_category'];
  if (explicit is String) return explicit;

  final name = record.loggerName;
  for (final entry in _loggerCategoryPrefixes.entries) {
    if (name == entry.key || name.startsWith('${entry.key}.')) {
      return entry.value;
    }
  }
  return 'system';
}
