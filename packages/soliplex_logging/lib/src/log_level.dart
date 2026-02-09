/// Log severity levels with numeric values for comparison.
enum LogLevel implements Comparable<LogLevel> {
  /// Very detailed debugging information.
  trace(0),

  /// Development debugging information.
  debug(100),

  /// Normal operational information.
  info(200),

  /// Recoverable issues or deprecation warnings.
  warning(300),

  /// Errors affecting functionality.
  error(400),

  /// Unrecoverable errors requiring restart.
  fatal(500);

  const LogLevel(this.value);

  /// Numeric value for level comparison.
  final int value;

  /// Display label for this level.
  String get label => name.toUpperCase();

  /// Returns true if this level is at or above [other].
  bool operator >=(LogLevel other) => value >= other.value;

  /// Returns true if this level is below [other].
  bool operator <(LogLevel other) => value < other.value;

  @override
  int compareTo(LogLevel other) => value.compareTo(other.value);
}
