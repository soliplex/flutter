import 'package:soliplex_logging/src/log_record.dart';

/// Redacts sensitive data from log records before they reach any sink.
///
/// Applies three layers of protection:
/// 1. **Key redaction** — attribute keys matching a blocklist have their
///    values replaced with `[REDACTED]`.
/// 2. **Pattern scrubbing** — regex patterns (emails, SSNs, bearer tokens,
///    IP addresses) are replaced in message strings.
/// 3. **Stack trace trimming** — absolute file paths are stripped to
///    relative paths.
class LogSanitizer {
  /// Creates a sanitizer with optional additional keys and patterns.
  LogSanitizer({
    Set<String>? additionalKeys,
    List<RegExp>? additionalPatterns,
  })  : _blockedKeys = {
          ..._defaultBlockedKeys,
          if (additionalKeys != null) ...additionalKeys,
        },
        _patterns = [
          ..._defaultPatterns,
          if (additionalPatterns != null) ...additionalPatterns,
        ];

  static const _defaultBlockedKeys = {
    'password',
    'token',
    'auth',
    'authorization',
    'secret',
    'ssn',
    'credential',
  };

  static final _defaultPatterns = <RegExp>[
    // Email addresses
    RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
    // SSN (xxx-xx-xxxx)
    RegExp(r'\b\d{3}-\d{2}-\d{4}\b'),
    // Bearer tokens
    RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
    // IPv4 addresses
    RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'),
  ];

  /// Absolute path prefix pattern for stack trace trimming.
  static final _absolutePathPattern = RegExp(r'(/[^\s:]+/)(lib/|test/)');

  static const _redacted = '[REDACTED]';

  final Set<String> _blockedKeys;
  final List<RegExp> _patterns;

  /// Returns a new [LogRecord] with sensitive data redacted.
  ///
  /// The original record is not modified (it is `@immutable`).
  LogRecord sanitize(LogRecord record) {
    final scrubbedMessage = _scrubPatterns(record.message);
    final scrubbedAttributes = _redactKeys(record.attributes);
    final scrubbedStack = record.stackTrace != null
        ? StackTrace.fromString(_trimPaths(record.stackTrace.toString()))
        : null;

    return record.copyWith(
      message: scrubbedMessage,
      attributes: scrubbedAttributes,
      stackTrace: scrubbedStack,
    );
  }

  String _scrubPatterns(String input) {
    var result = input;
    for (final pattern in _patterns) {
      result = result.replaceAll(pattern, _redacted);
    }
    return result;
  }

  Map<String, Object> _redactKeys(Map<String, Object> attributes) {
    if (attributes.isEmpty) return attributes;

    final result = <String, Object>{};
    for (final entry in attributes.entries) {
      final keyLower = entry.key.toLowerCase();
      if (_blockedKeys.contains(keyLower)) {
        result[entry.key] = _redacted;
      } else {
        result[entry.key] = entry.value;
      }
    }
    return Map.unmodifiable(result);
  }

  String _trimPaths(String stackTrace) {
    return stackTrace.replaceAllMapped(_absolutePathPattern, (match) {
      return match.group(2)!;
    });
  }
}
