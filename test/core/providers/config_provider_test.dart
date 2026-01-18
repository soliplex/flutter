import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_frontend/core/models/app_config.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';

void main() {
  group('ConfigNotifier', () {
    setUp(() {
      // Clear SharedPreferences mock for each test
      SharedPreferences.setMockInitialValues({});
    });

    test('build returns platform default when no overrides', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final config = container.read(configProvider);

      // Platform default for native is localhost:8000
      expect(config.baseUrl, 'http://localhost:8000');
    });

    test('build returns defaultBackendUrlProvider when overridden', () {
      final container = ProviderContainer(
        overrides: [
          defaultBackendUrlProvider.overrideWithValue('https://api.test.com'),
        ],
      );
      addTearDown(container.dispose);

      final config = container.read(configProvider);

      expect(config.baseUrl, 'https://api.test.com');
    });

    test('build returns preloaded URL when available', () {
      final container = ProviderContainer(
        overrides: [
          defaultBackendUrlProvider
              .overrideWithValue('https://api.default.com'),
          preloadedBaseUrlProvider.overrideWithValue('https://saved.user.com'),
        ],
      );
      addTearDown(container.dispose);

      final config = container.read(configProvider);

      // Preloaded URL takes precedence over default
      expect(config.baseUrl, 'https://saved.user.com');
    });

    test('setBaseUrl persists URL to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(configProvider.notifier).setBaseUrl(
            'https://api.example.com',
          );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('backend_base_url'), 'https://api.example.com');
    });

    test('setBaseUrl updates state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(configProvider.notifier).setBaseUrl(
            'https://api.example.com',
          );

      final config = container.read(configProvider);
      expect(config.baseUrl, 'https://api.example.com');
    });

    test('setBaseUrl trims whitespace', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(configProvider.notifier).setBaseUrl(
            '  https://api.example.com  ',
          );

      final config = container.read(configProvider);
      expect(config.baseUrl, 'https://api.example.com');
    });

    test('setBaseUrl ignores empty URL', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialUrl = container.read(configProvider).baseUrl;

      await container.read(configProvider.notifier).setBaseUrl('');
      await container.read(configProvider.notifier).setBaseUrl('   ');

      expect(container.read(configProvider).baseUrl, initialUrl);
    });

    test('setBaseUrl ignores same URL', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set a URL first
      await container.read(configProvider.notifier).setBaseUrl(
            'https://api.example.com',
          );

      // Set the same URL - should be a no-op
      await container.read(configProvider.notifier).setBaseUrl(
            'https://api.example.com',
          );

      // Verify it was only saved once (state didn't change twice)
      expect(
        container.read(configProvider).baseUrl,
        'https://api.example.com',
      );
    });

    test('set directly updates state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(configProvider.notifier).set(
            const AppConfig(baseUrl: 'https://custom.example.com'),
          );

      final config = container.read(configProvider);
      expect(config.baseUrl, 'https://custom.example.com');
    });
  });

  group('loadSavedBaseUrl', () {
    test('returns saved URL from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'backend_base_url': 'https://saved.example.com',
      });

      final savedUrl = await loadSavedBaseUrl();

      expect(savedUrl, 'https://saved.example.com');
    });

    test('returns null when no URL saved', () async {
      SharedPreferences.setMockInitialValues({});

      final savedUrl = await loadSavedBaseUrl();

      expect(savedUrl, isNull);
    });

    test('returns null for empty saved URL', () async {
      SharedPreferences.setMockInitialValues({
        'backend_base_url': '',
      });

      final savedUrl = await loadSavedBaseUrl();

      expect(savedUrl, isNull);
    });
  });

  group('preloadedBaseUrlProvider', () {
    test('defaults to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(preloadedBaseUrlProvider), isNull);
    });

    test('can be overridden with saved URL', () {
      final container = ProviderContainer(
        overrides: [
          preloadedBaseUrlProvider.overrideWithValue('https://override.com'),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(preloadedBaseUrlProvider), 'https://override.com');
    });
  });

  group('defaultBackendUrlProvider', () {
    test('defaults to platform URL (localhost for native)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(defaultBackendUrlProvider),
        'http://localhost:8000',
      );
    });

    test('can be overridden with custom URL', () {
      final container = ProviderContainer(
        overrides: [
          defaultBackendUrlProvider.overrideWithValue('https://api.custom.com'),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(defaultBackendUrlProvider),
        'https://api.custom.com',
      );
    });
  });
}
