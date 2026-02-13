import 'dart:io';

import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client_native/src/clients/cronet_http_client.dart';
import 'package:soliplex_client_native/src/clients/cupertino_http_client.dart';

/// Creates platform-specific client for IO platforms.
///
/// Returns:
/// - [CronetHttpClient] on Android (uses Cronet via Google Play Services)
/// - [CupertinoHttpClient] on macOS and iOS (uses NSURLSession)
/// - [DartHttpClient] on all other platforms (Windows, Linux)
///
/// Note: Falls back to [DartHttpClient] if native bindings are unavailable
/// (e.g., in Flutter test environment or when Cronet/Play Services missing).
SoliplexHttpClient createPlatformClientImpl({
  Duration defaultTimeout = defaultHttpTimeout,
}) {
  if (Platform.isAndroid) {
    try {
      return CronetHttpClient(defaultTimeout: defaultTimeout);
    } catch (e) {
      // Fallback to DartHttpClient if Cronet unavailable
      // (e.g., Google Play Services missing)
      return DartHttpClient(defaultTimeout: defaultTimeout);
    }
  }
  if (Platform.isMacOS || Platform.isIOS) {
    try {
      return CupertinoHttpClient(defaultTimeout: defaultTimeout);
    } catch (e) {
      // Fallback to DartHttpClient if native bindings unavailable
      // (e.g., in Flutter test environment)
      return DartHttpClient(defaultTimeout: defaultTimeout);
    }
  }
  // Fallback to DartHttpClient for Windows, Linux
  return DartHttpClient(defaultTimeout: defaultTimeout);
}
