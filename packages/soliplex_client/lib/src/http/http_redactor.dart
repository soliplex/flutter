/// Centralized redaction logic for HTTP traffic logging.
///
/// Provides static methods to redact sensitive information from headers,
/// URIs, and JSON bodies before they are emitted to observers. This ensures
/// sensitive data never crosses the observer boundary.
///
/// Redaction is always enabled and cannot be bypassed.
class HttpRedactor {
  HttpRedactor._();

  /// Placeholder text for redacted values.
  static const _redacted = '[REDACTED]';

  /// Placeholder for redacted auth endpoint bodies.
  static const _redactedAuthEndpoint = '[REDACTED - Auth Endpoint]';

  /// Headers that are always redacted (exact match, case-insensitive).
  static const _exactMatchHeaders = {
    'authorization',
    'proxy-authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'x-auth-token',
    'x-csrf-token',
    'x-xsrf-token',
    'x-forwarded-for',
    'x-real-ip',
  };

  /// Substrings that trigger header redaction (case-insensitive).
  static const _substringMatchHeaders = [
    'token',
    'key',
    'secret',
    'password',
    'auth',
    'session',
    'credential',
    'bearer',
  ];

  /// Query parameters that are always redacted (case-insensitive).
  static const _sensitiveParams = {
    'token',
    'access_token',
    'refresh_token',
    'id_token',
    'code',
    'client_secret',
    'state',
    'code_verifier',
    'session_state',
    'api_key',
    'password',
    'secret',
    'key',
    'credential',
    'auth',
  };

  /// JSON field names that are always redacted (case-insensitive).
  static const _sensitiveFields = {
    'password',
    'secret',
    'token',
    'access_token',
    'refresh_token',
    'id_token',
    'api_key',
    'client_secret',
    'authorization',
    'credential',
    'bearer',
    'session_token',
    'private_key',
    'signing_key',
    'encryption_key',
  };

  /// URL path patterns that indicate auth endpoints (case-insensitive).
  static const _authEndpointPatterns = [
    '/oauth',
    '/token',
    '/auth',
    '/login',
    '/signin',
    '/authenticate',
    '/password',
    '/reset-password',
    '/forgot-password',
    '/register',
    '/signup',
    '/session',
    '/sessions',
    '/2fa',
    '/mfa',
    '/otp',
  ];

  /// Redacts sensitive header values.
  ///
  /// Headers are redacted if:
  /// - Name matches exactly (case-insensitive): Authorization, Cookie, etc.
  /// - Name contains sensitive substring: token, key, secret, etc.
  static Map<String, String> redactHeaders(Map<String, String> headers) {
    return headers.map((name, value) {
      final lowerName = name.toLowerCase();

      // Check exact match
      if (_exactMatchHeaders.contains(lowerName)) {
        return MapEntry(name, _redacted);
      }

      // Check substring match
      for (final substring in _substringMatchHeaders) {
        if (lowerName.contains(substring)) {
          return MapEntry(name, _redacted);
        }
      }

      return MapEntry(name, value);
    });
  }

  /// Redacts sensitive query parameter values.
  ///
  /// Returns the original URI unchanged if no sensitive parameters are present.
  static Uri redactUri(Uri uri) {
    if (uri.queryParameters.isEmpty) return uri;

    final hasSensitiveParams = uri.queryParameters.keys.any(
      (key) => _sensitiveParams.contains(key.toLowerCase()),
    );
    if (!hasSensitiveParams) return uri;

    final redactedParams = uri.queryParameters.map((key, value) {
      if (_sensitiveParams.contains(key.toLowerCase())) {
        return MapEntry(key, _redacted);
      }
      return MapEntry(key, value);
    });

    return uri.replace(queryParameters: redactedParams);
  }

  /// Redacts sensitive fields from a JSON body.
  ///
  /// For auth endpoints, the entire body is redacted. For other endpoints,
  /// sensitive field names are recursively redacted.
  ///
  /// Returns the redacted body, which may be a Map, List, String, or null.
  static dynamic redactJsonBody(dynamic body, Uri uri) {
    if (body == null) return null;

    // Auth endpoints: redact entire body
    if (_isAuthEndpoint(uri)) {
      return _redactedAuthEndpoint;
    }

    return _redactValue(body);
  }

  /// Redacts a raw string body for auth endpoints only.
  ///
  /// Non-auth endpoints return the string unchanged.
  static String redactString(String body, Uri uri) {
    if (_isAuthEndpoint(uri)) {
      return _redactedAuthEndpoint;
    }
    return body;
  }

  /// Checks if the URI path indicates an auth endpoint.
  static bool _isAuthEndpoint(Uri uri) {
    final lowerPath = uri.path.toLowerCase();
    return _authEndpointPatterns.any(lowerPath.contains);
  }

  /// Recursively redacts sensitive values in JSON structures.
  static dynamic _redactValue(dynamic value) {
    if (value is Map) {
      return _redactMap(value);
    } else if (value is List) {
      return value.map(_redactValue).toList();
    }
    return value;
  }

  /// Redacts sensitive fields in a map.
  static Map<String, dynamic> _redactMap(Map<dynamic, dynamic> map) {
    return map.map((key, value) {
      final keyStr = key.toString();
      if (_sensitiveFields.contains(keyStr.toLowerCase())) {
        return MapEntry(keyStr, _redacted);
      }
      return MapEntry(keyStr, _redactValue(value));
    });
  }
}
