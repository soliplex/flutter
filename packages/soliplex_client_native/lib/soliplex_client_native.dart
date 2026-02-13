/// Native HTTP clients for soliplex_client.
///
/// Provides platform-optimized HTTP clients:
/// - `CronetHttpClient` for Android using Cronet (HTTP/2, HTTP/3, QUIC)
/// - `CupertinoHttpClient` for iOS and macOS using NSURLSession
/// - `createPlatformClient` for automatic platform detection
///
/// Example:
/// ```dart
/// import 'package:soliplex_client/soliplex_client.dart';
/// import 'package:soliplex_client_native/soliplex_client_native.dart';
///
/// // Auto-detect platform
/// final client = createPlatformClient();
///
/// // Or use specific client
/// final cupertinoClient = CupertinoHttpClient();
/// final cronetClient = CronetHttpClient();
/// ```
library soliplex_client_native;

export 'src/clients/clients.dart';
export 'src/platform/platform.dart';
