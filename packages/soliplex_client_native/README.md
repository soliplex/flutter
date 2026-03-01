# soliplex_client_native

Platform-optimized HTTP adapters for `soliplex_client` on iOS and macOS.

## Quick Start

```bash
cd packages/soliplex_client_native
flutter pub get
flutter test
dart format . --set-exit-if-changed
flutter analyze --fatal-infos
```

## Architecture

### Clients

- `CupertinoHttpClient` -- implements `SoliplexHttpClient` using Apple's native `NSURLSession` via `cupertino_http`; provides HTTP/2, system proxy/VPN support, and better energy efficiency on iOS/macOS

### Platform Detection

- `createPlatformClient()` -- factory function that auto-detects the platform and returns `CupertinoHttpClient` on Apple or falls back to `DartHttpClient` elsewhere

## Dependencies

- `soliplex_client` -- `SoliplexHttpClient` interface, `HttpResponse`, `NetworkException`, `DartHttpClient` fallback
- `cupertino_http` -- Apple NSURLSession bindings
- `http` -- Dart HTTP types
- `flutter` -- Flutter SDK (required for platform channel access)
- `meta` -- annotations

## Example

```dart
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client_native/soliplex_client_native.dart';

void main() {
  // Auto-detect: CupertinoHttpClient on Apple, DartHttpClient elsewhere
  final client = createPlatformClient();

  // Or use CupertinoHttpClient directly on iOS/macOS
  final cupertinoClient = CupertinoHttpClient(
    defaultTimeout: Duration(seconds: 30),
  );

  // Plug into soliplex_client transport layer
  final transport = HttpTransport(client: client);
  final urlBuilder = UrlBuilder('http://localhost:8000');
  final api = SoliplexApi(transport: transport, urlBuilder: urlBuilder);
}
```
