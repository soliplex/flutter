// ============================================================================
// API CONTRACT TESTS - soliplex_client_native
// ============================================================================
//
// !! MAJOR VERSION BUMP REQUIRED !!
//
// If these tests fail or need modification due to codebase changes, it means
// the public API has changed in a breaking way. You MUST:
//
//   1. Increment the MAJOR version in pubspec.yaml (e.g., 1.0.0 -> 2.0.0)
//   2. Use a conventional commit with "BREAKING CHANGE:" in the footer
//   3. Update these tests to reflect the new API
//
// These tests exist to protect external consumers of this library. Breaking
// changes without a major version bump will break their builds.
//
// ============================================================================
//
// IMPORTANT: Only import from the public library entry point.
//
// Note: CupertinoHttpClient is only available on dart:io platforms (iOS/macOS).
// On web, only createPlatformClient is exported. These tests verify the
// cross-platform API that all consumers should use.
//
// ignore_for_file: unused_local_variable
// Redundant arguments are intentional - we test that parameters exist:
// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client_native/soliplex_client_native.dart';

void main() {
  group('soliplex_client_native public API contract', () {
    group('createPlatformClient', () {
      test('function exists and returns SoliplexHttpClient', () {
        final client = createPlatformClient();

        expect(client, isA<SoliplexHttpClient>());
        client.close();
      });

      test('function accepts defaultTimeout parameter', () {
        final client = createPlatformClient(
          defaultTimeout: const Duration(seconds: 60),
        );

        expect(client, isA<SoliplexHttpClient>());
        client.close();
      });

      test('returned client has expected interface', () {
        final client = createPlatformClient();

        // Verify SoliplexHttpClient methods are available
        expect(client.request, isA<Function>());
        expect(client.requestStream, isA<Function>());
        expect(client.close, isA<Function>());

        client.close();
      });
    });

    group('consumer simulation: platform-aware HTTP setup', () {
      test('typical setup using createPlatformClient', () {
        // Simulates how an external project would set up HTTP
        final httpClient = createPlatformClient(
          defaultTimeout: const Duration(seconds: 30),
        );

        // Wrap with observability
        final observableClient = ObservableHttpClient(
          client: httpClient,
          observers: [],
        );

        // Create transport
        final transport = HttpTransport(
          client: observableClient,
          defaultTimeout: const Duration(seconds: 60),
        );

        // Create API client
        final urlBuilder = UrlBuilder('https://api.myapp.com/v1');
        final api = SoliplexApi(
          transport: transport,
          urlBuilder: urlBuilder,
        );

        expect(api, isA<SoliplexApi>());
        api.close();
      });

      test('setup with HttpClientAdapter for third-party libraries', () {
        // Simulates using our client with libraries that expect http.Client
        final platformClient = createPlatformClient();
        final adapter = HttpClientAdapter(client: platformClient);

        // adapter can now be passed to libraries expecting http.Client
        expect(adapter.client, isA<SoliplexHttpClient>());

        adapter.close();
      });

      test('multiple clients can be created independently', () {
        final client1 = createPlatformClient(
          defaultTimeout: const Duration(seconds: 30),
        );
        final client2 = createPlatformClient(
          defaultTimeout: const Duration(seconds: 60),
        );

        expect(client1, isNot(same(client2)));

        client1.close();
        client2.close();
      });
    });
  });
}
