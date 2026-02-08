import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';

/// Logs all Riverpod provider state changes to soliplex_logging.
///
/// This gives LLMs (via `get_app_logs`) and integration tests (via
/// `TestLogHarness` / `MemorySink`) full visibility into provider state
/// transitions at debug level.
///
/// Wire into `ProviderScope` at app startup:
/// ```dart
/// ProviderScope(
///   observers: [LoggingProviderObserver()],
///   child: const SoliplexApp(),
/// )
/// ```
base class LoggingProviderObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    final name = context.provider.name ?? '${context.provider.runtimeType}';
    Loggers.state.debug('$name: $newValue');
  }
}
