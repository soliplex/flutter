import 'dart:async';

import 'package:soliplex_frontend/core/models/thread_key.dart';

/// Zone key for propagating [ThreadKey] to tool executors.
///
/// When `ActiveRunNotifier` executes tools, it wraps the execution in
/// [runInToolExecutionZone] so that downstream executors (like
/// `execute_python`) can determine which thread they're running for
/// via [activeThreadKey].
const Symbol _threadKeySymbol = #toolExecutionThreadKey;

/// Returns the [ThreadKey] stored in the current zone, or `null` if
/// the code is running outside a tool execution zone.
ThreadKey? get activeThreadKey => Zone.current[_threadKeySymbol] as ThreadKey?;

/// Runs [body] in a zone that stores [key] as the active thread key.
///
/// Tool executors called within [body] can read the key via
/// [activeThreadKey] to look up per-thread resources (e.g. bridge cache).
Future<T> runInToolExecutionZone<T>(
  ThreadKey key,
  Future<T> Function() body,
) {
  return runZoned(body, zoneValues: {_threadKeySymbol: key});
}
