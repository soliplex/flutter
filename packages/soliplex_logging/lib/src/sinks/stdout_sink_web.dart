import 'package:soliplex_logging/src/log_record.dart';

/// No-op implementation for web platform.
///
/// Called by `StdoutSink.write` via conditional import on web platform.
/// Web browsers don't have a stdout concept, so this is intentionally empty.
void writeToStdout(
  LogRecord record, {
  required bool useColors,
  required bool showTimestamp,
}) {
  // Intentionally empty - web has no stdout concept.
}
