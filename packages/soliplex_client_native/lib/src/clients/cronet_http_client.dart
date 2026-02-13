import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cronet_http/cronet_http.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:soliplex_client/soliplex_client.dart';

/// HTTP client using Google's Cronet via cronet_http.
///
/// Provides native HTTP support on Android with benefits including:
/// - HTTP/2 and HTTP/3 (QUIC) support
/// - Connection pooling and multiplexing
/// - Brotli compression
/// - Automatic proxy and VPN support
/// - Continuous security updates via Google Play Services
///
/// Example:
/// ```dart
/// final client = CronetHttpClient();
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
class CronetHttpClient implements SoliplexHttpClient {
  /// Creates a Cronet HTTP client.
  ///
  /// Parameters:
  /// - [engine]: Optional CronetEngine. If not provided, the default
  ///   Cronet engine (backed by Google Play Services) is used.
  /// - [defaultTimeout]: Default timeout for requests.
  CronetHttpClient({
    CronetEngine? engine,
    this.defaultTimeout = defaultHttpTimeout,
  }) : _client = engine != null
            ? CronetClient.fromCronetEngine(engine, closeEngine: true)
            : CronetClient.defaultCronetEngine();

  /// Creates a Cronet HTTP client with a custom client for testing.
  ///
  /// This constructor allows injecting a mock client for unit testing.
  @visibleForTesting
  CronetHttpClient.forTesting({
    required http.Client client,
    this.defaultTimeout = defaultHttpTimeout,
  }) : _client = client;

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

    controller = StreamController<List<int>>(
      onListen: () async {
        try {
          final streamedResponse = await _client.send(request);

          // Check for HTTP errors before streaming
          if (streamedResponse.statusCode >= 400) {
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
            controller.add,
            onError: (Object error, StackTrace stackTrace) {
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
            },
            onDone: controller.close,
            cancelOnError: true,
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
      onCancel: () async {
        await subscription?.cancel();
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
        'Cannot use CronetHttpClient after close() was called',
      );
    }
  }
}
