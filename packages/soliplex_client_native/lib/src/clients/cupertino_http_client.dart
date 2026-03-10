import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:soliplex_client/soliplex_client.dart';

/// HTTP client using Apple's NSURLSession via cupertino_http.
///
/// Provides native HTTP support on iOS and macOS with benefits including:
/// - Automatic proxy and VPN support
/// - HTTP/2 and HTTP/3 support
/// - System certificate trust evaluation
/// - Better battery efficiency
///
/// Example:
/// ```dart
/// final client = CupertinoHttpClient();
/// try {
///   final response = await client.request(
///     'GET',
///     Uri.parse('https://api.example.com/data'),
///   );
///   print(response.body);
/// } finally {
///   client.close();
/// }
/// ```
class CupertinoHttpClient implements SoliplexHttpClient {
  /// Creates a Cupertino HTTP client.
  ///
  /// Parameters:
  /// - [configuration]: Optional URLSessionConfiguration. If not provided,
  ///   an ephemeral configuration is created with [defaultTimeout] applied
  ///   to timeoutIntervalForRequest. When providing your own configuration,
  ///   you are responsible for its timeout settings.
  /// - [defaultTimeout]: Default timeout for requests.
  CupertinoHttpClient({
    URLSessionConfiguration? configuration,
    this.defaultTimeout = defaultHttpTimeout,
  }) : _client = CupertinoClient.fromSessionConfiguration(
          configuration ?? _createConfiguration(defaultTimeout),
        );

  /// Creates a Cupertino HTTP client with a custom client for testing.
  ///
  /// This constructor allows injecting a mock client for unit testing.
  @visibleForTesting
  CupertinoHttpClient.forTesting({
    required http.Client client,
    this.defaultTimeout = defaultHttpTimeout,
  }) : _client = client;

  /// Creates a URLSessionConfiguration with the given timeout.
  static URLSessionConfiguration _createConfiguration(Duration timeout) {
    return URLSessionConfiguration.ephemeralSessionConfiguration()
      ..timeoutIntervalForRequest = timeout;
  }

  final http.Client _client;

  /// Default timeout for requests when not specified per-request.
  final Duration defaultTimeout;

  bool _closed = false;

  @override
  Future<HttpResponse> request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    _checkNotClosed();

    final effectiveTimeout = timeout ?? defaultTimeout;
    final request = _createRequest(method, uri, headers, body);

    try {
      final streamedResponse = await _client.send(request).timeout(
        effectiveTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Request timed out after ${effectiveTimeout.inSeconds}s',
            effectiveTimeout,
          );
        },
      );

      final bodyBytes = await streamedResponse.stream.toBytes().timeout(
        effectiveTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Response body timed out after ${effectiveTimeout.inSeconds}s',
            effectiveTimeout,
          );
        },
      );

      return HttpResponse(
        statusCode: streamedResponse.statusCode,
        bodyBytes: Uint8List.fromList(bodyBytes),
        headers: _normalizeHeaders(streamedResponse.headers),
        reasonPhrase: streamedResponse.reasonPhrase,
      );
    } on TimeoutException catch (e, stackTrace) {
      throw NetworkException(
        message: e.message ?? 'Request timed out',
        isTimeout: true,
        originalError: e,
        stackTrace: stackTrace,
      );
    } on http.ClientException catch (e, stackTrace) {
      throw NetworkException(
        message: 'Client error: ${e.message}',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Stream<List<int>> requestStream(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    _checkNotClosed();

    final request = _createRequest(method, uri, headers, body);

    late StreamController<List<int>> controller;
    StreamSubscription<List<int>>? subscription;
    Timer? inactivityTimer;
    var isCancelled = false;

    controller = StreamController<List<int>>(
      onListen: () async {
        try {
          final streamedResponse = await _client.send(request);

          // If cancelled while awaiting headers, drain to release socket.
          if (isCancelled) {
            unawaited(streamedResponse.stream.listen((_) {}).cancel());
            return;
          }

          // Check for HTTP errors before streaming
          if (streamedResponse.statusCode >= 400) {
            // Drain the body stream to release the underlying socket.
            unawaited(streamedResponse.stream.listen((_) {}).cancel());
            controller.addError(
              NetworkException(
                message: 'HTTP ${streamedResponse.statusCode}: '
                    '${streamedResponse.reasonPhrase}',
              ),
            );
            await controller.close();
            return;
          }

          subscription = streamedResponse.stream.listen(
            (data) {
              // Reset inactivity timer on every chunk.
              inactivityTimer?.cancel();
              inactivityTimer = null;
              controller.add(data);
            },
            onError: (Object error, StackTrace stackTrace) {
              // Swallow transient stream errors (e.g. ERR_NETWORK_CHANGED)
              // and start an inactivity timer. If real data resumes, the
              // timer is reset. If not, the stream closes after the timeout.
              if (error is http.ClientException) {
                controller.addError(
                  NetworkException(
                    message: 'Connection error: ${error.message}',
                    originalError: error,
                    stackTrace: stackTrace,
                  ),
                );
              } else {
                controller.addError(error, stackTrace);
              }

              // Start inactivity deadline — if no data arrives within 30s
              // after an error, the connection is truly dead.
              inactivityTimer ??= Timer(
                const Duration(seconds: 30),
                () {
                  subscription?.cancel();
                  if (!controller.isClosed) {
                    controller.close();
                  }
                },
              );
            },
            onDone: () {
              inactivityTimer?.cancel();
              controller.close();
            },
            // Don't auto-kill on error — let the inactivity timer decide.
            cancelOnError: false,
          );
        } on http.ClientException catch (e, stackTrace) {
          controller.addError(
            NetworkException(
              message: 'Client error: ${e.message}',
              originalError: e,
              stackTrace: stackTrace,
            ),
          );
          await controller.close();
        }
      },
      onCancel: () {
        isCancelled = true;
        inactivityTimer?.cancel();

        if (subscription == null) return;

        // Graceful drain: mute callbacks to prevent pumping data/errors
        // into a closed controller, then give the server a brief window
        // to send TCP FIN before force-cancelling.
        subscription!.onData((_) {});
        subscription!.onError((_) {});

        // Fire-and-forget so the caller's cancel() resolves immediately.
        unawaited(() async {
          try {
            await subscription!.asFuture<void>().timeout(
                  const Duration(seconds: 2),
                );
          } catch (_) {
            await subscription!.cancel();
          }
        }());
      },
    );

    return controller.stream;
  }

  @override
  void close() {
    if (!_closed) {
      _closed = true;
      _client.close();
    }
  }

  /// Creates an HTTP request with the given parameters.
  http.Request _createRequest(
    String method,
    Uri uri,
    Map<String, String>? headers,
    Object? body,
  ) {
    final request = http.Request(method.toUpperCase(), uri);

    if (headers != null) {
      request.headers.addAll(headers);
    }

    if (body != null) {
      if (body is String) {
        // Set content-type before body to prevent http package from overriding
        request.headers['content-type'] ??= 'text/plain; charset=utf-8';
        request.body = body;
      } else if (body is List<int>) {
        request.headers['content-type'] ??= 'application/octet-stream';
        request.bodyBytes = body;
      } else if (body is Map<String, dynamic>) {
        // Set content-type before body to prevent http package from overriding
        request.headers['content-type'] ??= 'application/json; charset=utf-8';
        request.body = jsonEncode(body);
      } else {
        throw ArgumentError(
          'Unsupported body type: ${body.runtimeType}. '
          'Use String, List<int>, or Map<String, dynamic>.',
        );
      }
    }

    return request;
  }

  /// Normalizes headers by converting keys to lowercase.
  Map<String, String> _normalizeHeaders(Map<String, String> headers) {
    return headers.map((key, value) => MapEntry(key.toLowerCase(), value));
  }

  /// Checks that the client has not been closed.
  void _checkNotClosed() {
    if (_closed) {
      throw StateError(
        'Cannot use CupertinoHttpClient after close() was called',
      );
    }
  }
}
