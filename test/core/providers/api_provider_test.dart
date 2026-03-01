import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/models/app_config.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';
import 'package:soliplex_frontend/core/providers/http_log_provider.dart';

import '../../helpers/test_helpers.dart';

/// HTTP client wrapper that tracks whether close() was called.
///
/// Used to verify that shared HTTP clients are NOT prematurely closed
/// when dependent providers are disposed.
class CloseTrackingHttpClient extends http.BaseClient {
  CloseTrackingHttpClient(this._inner);

  final http.Client _inner;
  bool closeCalled = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request);
  }

  @override
  void close() {
    closeCalled = true;
    _inner.close();
  }
}

/// HTTP client wrapper that counts how many times close() is called.
class CloseCountingHttpClient extends http.BaseClient {
  CloseCountingHttpClient(this._inner, {required this.onClose});

  final http.Client _inner;
  final void Function() onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request);
  }

  @override
  void close() {
    onClose();
    _inner.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerMocktailFallbacks);

  group('httpTransportProvider', () {
    test('creates HttpTransport instance', () {
      final container = createContainerWithMockedAuth();
      addTearDown(container.dispose);

      final transport = container.read(httpTransportProvider);

      expect(transport, isA<HttpTransport>());
    });

    test('is singleton across multiple reads', () {
      final container = createContainerWithMockedAuth();
      addTearDown(container.dispose);

      final transport1 = container.read(httpTransportProvider);
      final transport2 = container.read(httpTransportProvider);

      expect(identical(transport1, transport2), isTrue);
    });

    // Note: This test verifies disposal doesn't throw. Verifying that
    // resources are actually cleaned up (close() called) requires mocking
    // and is covered by integration tests at the feature level.
    test('container disposal completes without errors', () async {
      final container = createContainerWithMockedAuth()
        ..read(httpTransportProvider);

      // Wait for AuthNotifier's async _restoreSession to complete
      await waitForAuthRestore(container);

      expect(container.dispose, returnsNormally);
    });
  });

  group('urlBuilderProvider', () {
    test('creates UrlBuilder with base URL from config', () {
      const testConfig = AppConfig(baseUrl: 'http://localhost:8000');

      final container = createContainerWithMockedAuth(
        overrides: [configProviderOverride(testConfig)],
      );
      addTearDown(container.dispose);

      final urlBuilder = container.read(urlBuilderProvider);

      expect(urlBuilder, isA<UrlBuilder>());
      // Verify it uses the config's baseUrl with /api/v1 suffix
      expect(
        urlBuilder.build(path: '/rooms'),
        Uri.parse('http://localhost:8000/api/v1/rooms'),
      );
    });

    test('uses different baseUrl for different config', () {
      const config1 = AppConfig(baseUrl: 'http://localhost:8000');
      const config2 = AppConfig(baseUrl: 'http://localhost:9000');

      // Test with config1
      final container1 = createContainerWithMockedAuth(
        overrides: [configProviderOverride(config1)],
      );
      addTearDown(container1.dispose);

      final urlBuilder1 = container1.read(urlBuilderProvider);
      expect(
        urlBuilder1.build(path: '/rooms'),
        Uri.parse('http://localhost:8000/api/v1/rooms'),
      );

      // Test with config2 in separate container
      final container2 = createContainerWithMockedAuth(
        overrides: [configProviderOverride(config2)],
      );
      addTearDown(container2.dispose);

      final urlBuilder2 = container2.read(urlBuilderProvider);
      expect(
        urlBuilder2.build(path: '/rooms'),
        Uri.parse('http://localhost:9000/api/v1/rooms'),
      );
    });
  });

  group('apiProvider', () {
    test('creates SoliplexApi instance', () {
      final container = createContainerWithMockedAuth();
      addTearDown(container.dispose);

      final api = container.read(apiProvider);

      expect(api, isA<SoliplexApi>());
    });

    test('is singleton across multiple reads', () {
      final container = createContainerWithMockedAuth();
      addTearDown(container.dispose);

      final api1 = container.read(apiProvider);
      final api2 = container.read(apiProvider);

      expect(identical(api1, api2), isTrue);
    });

    test('shares transport with agUiClientProvider via shared client', () {
      final container = createContainerWithMockedAuth();
      addTearDown(container.dispose);

      // Both apiProvider and agUiClientProvider should use the same
      // underlying observable client for unified HTTP logging
      final sharedClient = container.read(authenticatedClientProvider);

      // Read both API clients
      container
        ..read(apiProvider)
        ..read(agUiClientProvider);

      // Verify the shared client is still the same instance
      final clientAfterClients = container.read(authenticatedClientProvider);
      expect(identical(sharedClient, clientAfterClients), isTrue);
    });

    // Note: This test verifies disposal doesn't throw. Verifying that
    // resources are actually cleaned up (close() called) requires mocking
    // and is covered by integration tests at the feature level.
    test('container disposal completes without errors', () async {
      final container = createContainerWithMockedAuth()..read(apiProvider);

      // Wait for AuthNotifier's async _restoreSession to complete
      await waitForAuthRestore(container);

      expect(container.dispose, returnsNormally);
    });

    test('creates different instances for different configs', () {
      const config1 = AppConfig(baseUrl: 'http://localhost:8000');
      const config2 = AppConfig(baseUrl: 'http://localhost:9000');

      // Test with config1
      final container1 = createContainerWithMockedAuth(
        overrides: [configProviderOverride(config1)],
      );
      addTearDown(container1.dispose);

      final api1 = container1.read(apiProvider);
      expect(api1, isA<SoliplexApi>());

      // Test with config2 in separate container
      final container2 = createContainerWithMockedAuth(
        overrides: [configProviderOverride(config2)],
      );
      addTearDown(container2.dispose);

      final api2 = container2.read(apiProvider);
      expect(api2, isA<SoliplexApi>());

      // APIs should be different instances for different configs
      expect(identical(api1, api2), isFalse);
    });
  });

  group('Provider integration', () {
    test('all providers work together correctly', () {
      const testConfig = AppConfig(baseUrl: 'http://localhost:8000');

      final container = createContainerWithMockedAuth(
        overrides: [configProviderOverride(testConfig)],
      );
      addTearDown(container.dispose);

      // Read all providers
      final transport = container.read(httpTransportProvider);
      final urlBuilder = container.read(urlBuilderProvider);
      final api = container.read(apiProvider);

      // Verify all are properly instantiated
      expect(transport, isA<HttpTransport>());
      expect(urlBuilder, isA<UrlBuilder>());
      expect(api, isA<SoliplexApi>());

      // Verify URL builder has correct base URL
      expect(
        urlBuilder.build(path: '/rooms'),
        Uri.parse('http://localhost:8000/api/v1/rooms'),
      );
    });
  });

  group('authenticatedClientProvider', () {
    test('creates SoliplexHttpClient instance', () {
      final container = createContainerWithMockedAuth();
      addTearDown(container.dispose);

      final client = container.read(authenticatedClientProvider);

      // Returns authenticated wrapper around ObservableHttpClient
      expect(client, isA<SoliplexHttpClient>());
    });

    test('is singleton across multiple reads', () {
      final container = createContainerWithMockedAuth();
      addTearDown(container.dispose);

      final client1 = container.read(authenticatedClientProvider);
      final client2 = container.read(authenticatedClientProvider);

      expect(identical(client1, client2), isTrue);
    });

    test('initializes HttpLogNotifier dependency', () {
      final container = createContainerWithMockedAuth();
      addTearDown(container.dispose);

      // Reading the observable client should initialize the log notifier
      container.read(authenticatedClientProvider);

      // The log notifier should be accessible and functional
      final logNotifier = container.read(httpLogProvider.notifier);
      expect(logNotifier, isA<HttpLogNotifier>());
    });
  });

  group('shared client', () {
    test(
      'httpTransportProvider and soliplexHttpClientProvider share same client',
      () {
        final container = createContainerWithMockedAuth();
        addTearDown(container.dispose);

        // Read the observable client directly
        final sharedClient = container.read(authenticatedClientProvider);

        // Read the client from soliplexHttpClientProvider
        final httpClient = container.read(soliplexHttpClientProvider);

        // They should be the same instance
        expect(identical(sharedClient, httpClient), isTrue);
      },
    );

    test('httpTransportProvider depends on authenticatedClientProvider', () {
      final container = createContainerWithMockedAuth();
      addTearDown(container.dispose);

      // Read observable client first to establish the shared instance
      final sharedClient = container.read(authenticatedClientProvider);

      // Read the transport - it should use the same client
      container.read(httpTransportProvider);

      // Reading observable client again should return same instance,
      // proving the transport didn't create a separate client
      final clientAfterTransport = container.read(authenticatedClientProvider);
      expect(identical(sharedClient, clientAfterTransport), isTrue);

      // Verify client implements SoliplexHttpClient interface
      expect(sharedClient, isA<SoliplexHttpClient>());
    });
  });

  group('toolRegistryProvider', () {
    test('returns ToolRegistry with debug random_number tool by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final registry = container.read(toolRegistryProvider);

      expect(registry.toolDefinitions, hasLength(1));
      expect(
        registry.toolDefinitions.first.name,
        equals('random_number'),
      );
    });

    test('can be overridden with tools', () {
      final tool = ClientTool(
        definition: const Tool(name: 'test_tool', description: 'A test tool'),
        executor: (_) async => 'result',
      );
      final container = ProviderContainer(
        overrides: [
          toolRegistryProvider
              .overrideWithValue(const ToolRegistry().register(tool)),
        ],
      );
      addTearDown(container.dispose);

      final registry = container.read(toolRegistryProvider);

      expect(registry.toolDefinitions, hasLength(1));
      expect(registry.toolDefinitions.first.name, equals('test_tool'));
    });
  });

  group('Resource ownership - config change does not close shared client', () {
    // Regression tests for https://github.com/soliplex/flutter/issues/27
    // When agUiClientProvider is disposed (due to config change), it must NOT
    // close the shared HTTP client that was injected via dependency injection.
    //
    // The bug: AgUiClient.close() calls httpClient.close() which closes the
    // shared HttpClientAdapter, which in turn closes the shared
    // SoliplexHttpClient, breaking all other HTTP consumers.

    test(
      'agUiClientProvider disposal does not close shared httpClient',
      () async {
        const config1 = AppConfig(baseUrl: 'http://localhost:8000');

        // Create a wrapper to track close() calls
        final trackingClient = CloseTrackingHttpClient(
          http.Client(), // Dummy client for testing
        );

        // Create container with mock config and tracking httpClient
        final authMocks = createMockedAuthDependencies();
        final container = ProviderContainer(
          overrides: [
            ...authMocks.overrides,
            configProvider.overrideWith(
              () => MockConfigNotifier(initialConfig: config1),
            ),
            // Override httpClientProvider to return our tracking client
            httpClientProvider.overrideWithValue(trackingClient),
          ],
        );
        addTearDown(container.dispose);

        await waitForAuthRestore(container);

        // Verify client is not closed initially
        expect(trackingClient.closeCalled, isFalse);

        // Read agUiClientProvider - this creates an AgUiClient with our client
        final agUiClient1 = container.read(agUiClientProvider);
        expect(agUiClient1, isA<AgUiClient>());

        // Verify client is still not closed after creation
        expect(trackingClient.closeCalled, isFalse);

        // Now change the config - this invalidates agUiClientProvider
        // (because it watches configProvider), which triggers disposal
        await container
            .read(configProvider.notifier)
            .setBaseUrl('http://localhost:9000');

        // The agUiClientProvider should be a new instance after config change
        final agUiClient2 = container.read(agUiClientProvider);
        expect(identical(agUiClient1, agUiClient2), isFalse);

        // CRITICAL: close() should NOT have been called on the shared client!
        // Before the fix: AgUiClient.close() → httpClient.close() → CLOSED
        // After the fix: AgUiClient.close() → wrapper.close() → NO-OP
        expect(
          trackingClient.closeCalled,
          isFalse,
          reason: 'AgUiClient disposal should NOT close the shared httpClient. '
              'This is the core bug in issue #27.',
        );
      },
    );

    test(
      'httpClientProvider invalidation does not close shared soliplexClient',
      () async {
        final authMocks = createMockedAuthDependencies();
        final container = ProviderContainer(overrides: authMocks.overrides);
        addTearDown(container.dispose);

        await waitForAuthRestore(container);

        // Read the underlying soliplexHttpClient
        final soliplexClient = container.read(soliplexHttpClientProvider);
        expect(soliplexClient, isA<SoliplexHttpClient>());

        // Read httpClientProvider, then invalidate to trigger its disposal
        container
          ..read(httpClientProvider)
          ..invalidate(httpClientProvider);

        // The underlying soliplexClient should still be the same instance.
        // If httpClientProvider.onDispose closed the soliplexClient, then
        // baseHttpClientProvider would likely recreate it (but it doesn't
        // because soliplexHttpClientProvider doesn't get invalidated).
        final soliplexClientAfter = container.read(soliplexHttpClientProvider);
        expect(
          identical(soliplexClient, soliplexClientAfter),
          isTrue,
          reason: 'Shared SoliplexHttpClient should not be closed when '
              'httpClientProvider is invalidated',
        );
      },
    );

    test(
      'multiple config changes do not cause cumulative close() calls',
      () async {
        const config1 = AppConfig(baseUrl: 'http://localhost:8000');

        // Track how many times close() is called
        var closeCallCount = 0;
        final countingClient = CloseCountingHttpClient(
          http.Client(),
          onClose: () => closeCallCount++,
        );

        final authMocks = createMockedAuthDependencies();
        final container = ProviderContainer(
          overrides: [
            ...authMocks.overrides,
            configProvider.overrideWith(
              () => MockConfigNotifier(initialConfig: config1),
            ),
            httpClientProvider.overrideWithValue(countingClient),
          ],
        );
        addTearDown(container.dispose);

        await waitForAuthRestore(container);

        // Read agUiClientProvider
        container.read(agUiClientProvider);

        // Change config multiple times
        for (var i = 0; i < 5; i++) {
          await container
              .read(configProvider.notifier)
              .setBaseUrl('http://localhost:${9000 + i}');
          // Read agUiClientProvider after each change (triggers disposal)
          container.read(agUiClientProvider);
        }

        // close() should NOT have been called at all
        // Before the fix: called 5 times (once per disposal)
        // After the fix: called 0 times
        expect(
          closeCallCount,
          equals(0),
          reason: 'Shared HTTP client close() should never be called during '
              'config changes. Got $closeCallCount calls.',
        );
      },
    );
  });
}
