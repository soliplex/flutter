/// Illustrates how to use `createPlatformClient` to get a platform-optimized
/// HTTP client for `SoliplexApi`.
///
/// On iOS/macOS this returns a `CupertinoHttpClient` backed by NSURLSession.
/// On other platforms it falls back to `DartHttpClient`.
library;

// ignore_for_file: unused_local_variable

import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client_native/soliplex_client_native.dart';

void main() {
  // Auto-detect the best HTTP client for the current platform.
  final client = createPlatformClient();

  // Plug into the soliplex_client transport layer.
  final transport = HttpTransport(client: client);
  final urlBuilder = UrlBuilder('http://localhost:8000');
  final api = SoliplexApi(transport: transport, urlBuilder: urlBuilder);

  // Or use CupertinoHttpClient directly on iOS/macOS:
  // final cupertinoClient = CupertinoHttpClient(
  //   defaultTimeout: Duration(seconds: 30),
  // );
}
