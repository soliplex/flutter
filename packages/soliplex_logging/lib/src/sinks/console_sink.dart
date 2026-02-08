import 'package:meta/meta.dart';
import 'package:soliplex_logging/src/log_record.dart';
import 'package:soliplex_logging/src/log_sink.dart';

// Native is the default, web overrides when js_interop is available.
import 'package:soliplex_logging/src/sinks/console_sink_native.dart'
    if (dart.library.js_interop) 'package:soliplex_logging/src/sinks/console_sink_web.dart'
    as platform;

/// Function type for console write operations.
///
/// Used for testing to capture log output without writing to the actual
/// console.
typedef ConsoleWriter = void Function(LogRecord record);

/// Log sink that outputs to the console.
///
/// On native platforms (iOS, macOS, Android, Windows, Linux), uses
/// `dart:developer` to write to the IDE debug console.
///
/// On web, uses browser's `console` API with appropriate methods
/// (debug, info, warn, error) based on log level.
class ConsoleSink implements LogSink {
  /// Creates a console sink.
  ///
  /// Set [enabled] to false to temporarily disable output.
  ///
  /// The [testWriter] parameter is for testing only - it allows capturing
  /// log output without writing to the actual console. When provided,
  /// records are passed to this function instead of the platform console.
  ConsoleSink({
    this.enabled = true,
    @visibleForTesting ConsoleWriter? testWriter,
  }) : _testWriter = testWriter;

  /// Whether this sink is enabled.
  bool enabled;

  final ConsoleWriter? _testWriter;

  @override
  void write(LogRecord record) {
    if (!enabled) return;

    // Use test writer if provided, otherwise delegate to platform.
    if (_testWriter != null) {
      _testWriter(record);
    } else {
      platform.writeToConsole(record);
    }
  }

  @override
  Future<void> flush() async {
    // Console output is unbuffered.
  }

  @override
  Future<void> close() async {
    enabled = false;
  }
}
