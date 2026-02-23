import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client_native/soliplex_client_native.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';
import 'package:soliplex_frontend/core/providers/http_log_provider.dart';

/// Provider for the client-side [ToolRegistry].
///
/// Default: empty registry (no tools). White-label apps override this in
/// [ProviderScope.overrides] to inject custom tool definitions:
///
/// ```dart
/// toolRegistryProvider.overrideWithValue(
///   const ToolRegistry()
///       .register(myGpsTool)
///       .register(myDbLookupTool),
/// ),
/// ```
final toolRegistryProvider = Provider<ToolRegistry>((ref) {
  return const ToolRegistry();
});

/// HTTP client wrapper that delegates all operations except close().
///
/// Used to inject a shared HTTP client into consumers that call close()
/// but shouldn't own the client lifecycle. The close() operation is a no-op,
/// allowing the client to remain active for other consumers.
///
/// This enforces the resource ownership principle: "Don't close resources
/// you don't own" at the type system level.
class _NonClosingHttpClient extends http.BaseClient {
  _NonClosingHttpClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request);
  }

  @override
  void close() {
    // No-op: lifecycle is managed by the provider, not the consumer
  }
}

/// Provider for the base observable HTTP client (without auth).
///
/// Creates a single [ObservableHttpClient] that wraps the platform client
/// and notifies [HttpLogNotifier] of all HTTP activity.
///
/// **Note**: Use [authenticatedClientProvider] for API requests; this provider
/// is the base client without authentication. Use this provider for:
/// - Token refresh calls (must not use authenticated client to avoid loops)
/// - Backend health checks (don't require authentication)
/// - Any other calls that should be observable but not authenticated
final baseHttpClientProvider = Provider<SoliplexHttpClient>((ref) {
  final baseClient = createPlatformClient();
  Loggers.http.debug('Platform HTTP client created');
  final observer = ref.watch(httpLogProvider.notifier);
  final observable = ObservableHttpClient(
    client: baseClient,
    observers: [observer],
  );
  Loggers.http.debug('Observable client created with 1 observer');
  ref.onDispose(() {
    try {
      observable.close();
    } catch (e, stack) {
      Loggers.http.error(
        'Error disposing observable client',
        error: e,
        stackTrace: stack,
      );
    }
  });
  return observable;
});

/// Provider for the shared HTTP client with auth token injection and refresh.
///
/// Wraps the observable client to automatically add Authorization header
/// when a token is available, and handles token refresh on expiry or 401.
///
/// This client is shared by both REST API ([httpTransportProvider]) and
/// SSE streaming ([soliplexHttpClientProvider]) to provide unified HTTP
/// logging, authentication, and token refresh.
///
/// **Decorator order**: `Refreshing(Authenticated(Observable(Platform)))`
/// - Refreshing handles proactive refresh and 401 retry (once only)
/// - Authenticated adds Authorization header
/// - Observer sees requests WITH auth headers (accurate logging)
/// - Observer sees all responses including 401s
///
/// **Lifecycle**: Lives for the entire app session. Closed when container
/// is disposed.
final authenticatedClientProvider = Provider<SoliplexHttpClient>((ref) {
  final observableClient = ref.watch(baseHttpClientProvider);
  final authNotifier = ref.watch(authProvider.notifier);

  // Inner client: adds Authorization header
  final authClient = AuthenticatedHttpClient(
    observableClient,
    () => ref.read(accessTokenProvider),
  );

  // Outer client: handles proactive refresh + 401 retry
  Loggers.http.debug('Authenticated client created');
  return RefreshingHttpClient(inner: authClient, refresher: authNotifier);
});

/// Provider for the HTTP transport layer.
///
/// Creates a singleton [HttpTransport] instance using the shared
/// [authenticatedClientProvider]. All HTTP requests through this transport
/// are logged to [httpLogProvider].
///
/// **Lifecycle**: This is a non-autoDispose provider because the HTTP
/// transport should live for the entire app session.
///
/// **Threading**: Safe to call from any isolate. The underlying
/// adapter uses dart:http which is isolate-safe.
final httpTransportProvider = Provider<HttpTransport>((ref) {
  final client = ref.watch(authenticatedClientProvider);
  final transport = HttpTransport(client: client);

  // Note: Don't dispose transport here - client is managed by
  // authenticatedClientProvider
  return transport;
});

/// Provider for the URL builder.
///
/// Creates a [UrlBuilder] configured with the base URL from [configProvider].
/// Automatically reconstructs when the config changes (e.g., user changes
/// backend URL in settings).
///
/// The URL builder appends `/api/v1` to the base URL to construct
/// API endpoint URLs.
final urlBuilderProvider = Provider<UrlBuilder>((ref) {
  final config = ref.watch(configProvider);
  Loggers.http.debug('URL builder created: ${config.baseUrl}/api/v1');
  return UrlBuilder('${config.baseUrl}/api/v1');
});

/// Provider for the SoliplexApi instance.
///
/// Creates a single API client instance for the app lifetime.
/// The client is configured using dependencies from [httpTransportProvider]
/// and [urlBuilderProvider].
///
/// **Lifecycle**: This is a non-autoDispose provider because the API client
/// should live for the entire app session. The client shares the HTTP
/// transport with other potential API clients.
///
/// **Dependency Graph**:
/// ```text
/// configProvider
///     ↓
/// urlBuilderProvider → apiProvider
///                         ↑
/// httpTransportProvider ──┘
/// ```
///
/// **Usage Example**:
/// ```dart
/// final api = ref.watch(apiProvider);
/// final rooms = await api.getRooms();
/// ```
///
/// **Error Handling**:
/// Methods throw [SoliplexException] subtypes:
/// - [NetworkException]: Connection failures, timeouts
/// - [AuthException]: 401/403 authentication errors
/// - [NotFoundException]: 404 resource not found
/// - [ApiException]: Other 4xx/5xx server errors
/// - [CancelledException]: Request was cancelled
final apiProvider = Provider<SoliplexApi>((ref) {
  final transport = ref.watch(httpTransportProvider);
  final urlBuilder = ref.watch(urlBuilderProvider);

  // Note: We don't register ref.onDispose(api.close) because api.close()
  // would close the shared transport. The transport is managed by
  // httpTransportProvider, and the underlying client is managed by
  // baseHttpClientProvider.
  Loggers.http.debug('API client created');
  return SoliplexApi(
    transport: transport,
    urlBuilder: urlBuilder,
    onWarning: Loggers.http.warning,
  );
});

/// Provider for the Soliplex HTTP client.
///
/// Returns the shared [authenticatedClientProvider] to ensure all HTTP activity
/// (both REST and SSE) is logged through [httpLogProvider].
final soliplexHttpClientProvider = Provider<SoliplexHttpClient>((ref) {
  return ref.watch(authenticatedClientProvider);
});

/// Provider for http.Client that uses our HTTP client stack.
///
/// This bridges our [SoliplexHttpClient] to the standard [http.Client]
/// interface, allowing libraries like AgUiClient to use our HTTP
/// infrastructure.
///
/// **Ownership**: This provider does NOT close the underlying client on
/// disposal. [HttpClientAdapter] is a thin stateless wrapper, and the
/// underlying [soliplexHttpClientProvider] manages its own lifecycle.
final httpClientProvider = Provider<http.Client>((ref) {
  final soliplexClient = ref.watch(soliplexHttpClientProvider);
  return HttpClientAdapter(client: soliplexClient);
});

/// Provider for the AG-UI client.
///
/// Creates an [AgUiClient] that uses our HTTP stack via [httpClientProvider].
/// This ensures AG-UI requests go through our platform adapters and observers.
///
/// **Ownership**: The httpClient is wrapped in [_NonClosingHttpClient] to
/// prevent AgUiClient.close() from closing the shared HTTP client. This
/// provider watches [configProvider], so it gets disposed when the backend
/// URL changes. Without the wrapper, disposal would close the shared client,
/// breaking all HTTP consumers. See: https://github.com/soliplex/flutter/issues/27
final agUiClientProvider = Provider<AgUiClient>((ref) {
  final httpClient = ref.watch(httpClientProvider);
  final config = ref.watch(configProvider);

  // Wrap in non-closing adapter to protect shared resource.
  // AgUiClient.close() will clean up its internal resources (streams, tokens)
  // but won't close the underlying shared HTTP client.
  final protectedClient = _NonClosingHttpClient(httpClient);

  Loggers.http.debug('AG-UI client created (timeout: 600s)');
  final client = AgUiClient(
    config: AgUiClientConfig(
      baseUrl: '${config.baseUrl}/api/v1',
      requestTimeout: const Duration(seconds: 600),
      connectionTimeout: const Duration(seconds: 600),
    ),
    httpClient: protectedClient,
  );

  ref.onDispose(client.close);
  return client;
});
