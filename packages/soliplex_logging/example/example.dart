/// Minimal example showing how to configure logging and emit log records.
///
/// ```bash
/// dart run example/example.dart
/// ```
library;

import 'package:soliplex_logging/soliplex_logging.dart';

void main() {
  // 1. Configure the log manager.
  final logManager = LogManager.instance
    ..minimumLevel = LogLevel.debug
    ..addSink(ConsoleSink());

  // 2. Get a named logger.
  final log = logManager.getLogger('MyApp');

  // 3. Emit log records at various levels.
  log
    ..info('Application started')
    ..debug('Loading configuration')
    ..warning('Cache miss for key "user:42"');

  try {
    throw const FormatException('bad input');
  } on FormatException catch (e, s) {
    log.error('Failed to parse input', error: e, stackTrace: s);
  }
}
