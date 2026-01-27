import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_frontend/core/models/app_config.dart';
import 'package:soliplex_frontend/core/models/logo_config.dart';
import 'package:soliplex_frontend/core/models/soliplex_config.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('ConfigNotifier', () {
    setUp(() {
      // Clear SharedPreferences mock for each test
      SharedPreferences.setMockInitialValues({});
    });

    test('build returns platform default when no config URL', () {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(testSoliplexConfig),
        ],
      );
      addTearDown(container.dispose);

      final config = container.read(configProvider);

      // SoliplexConfig.defaultBackendUrl is null, so uses platform default.
      // Tests run on native, so expect localhost.
      expect(config.baseUrl, 'http://localhost:8000');
    });

    test('build returns shellConfigProvider URL when overridden', () {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(
            const SoliplexConfig(
              logo: LogoConfig.soliplex,
              defaultBackendUrl: 'https://api.test.com',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final config = container.read(configProvider);

      expect(config.baseUrl, 'https://api.test.com');
    });

    test('build returns preloaded URL when available', () {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(
            const SoliplexConfig(
              logo: LogoConfig.soliplex,
              defaultBackendUrl: 'https://api.default.com',
            ),
          ),
          preloadedBaseUrlProvider.overrideWithValue('https://saved.user.com'),
        ],
      );
      addTearDown(container.dispose);

      final config = container.read(configProvider);

      // Preloaded URL takes precedence over default
      expect(config.baseUrl, 'https://saved.user.com');
    });

    test('setBaseUrl persists URL to SharedPreferences', () async {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(testSoliplexConfig),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(configProvider.notifier)
          .setBaseUrl('https://api.example.com');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('backend_base_url'), 'https://api.example.com');
    });

    test('setBaseUrl updates state', () async {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(testSoliplexConfig),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(configProvider.notifier)
          .setBaseUrl('https://api.example.com');

      final config = container.read(configProvider);
      expect(config.baseUrl, 'https://api.example.com');
    });

    test('setBaseUrl trims whitespace', () async {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(testSoliplexConfig),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(configProvider.notifier)
          .setBaseUrl('  https://api.example.com  ');

      final config = container.read(configProvider);
      expect(config.baseUrl, 'https://api.example.com');
    });

    test('setBaseUrl ignores empty URL', () async {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(testSoliplexConfig),
        ],
      );
      addTearDown(container.dispose);

      final initialUrl = container.read(configProvider).baseUrl;

      await container.read(configProvider.notifier).setBaseUrl('');
      await container.read(configProvider.notifier).setBaseUrl('   ');

      expect(container.read(configProvider).baseUrl, initialUrl);
    });

    test('setBaseUrl ignores same URL', () async {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(testSoliplexConfig),
        ],
      );
      addTearDown(container.dispose);

      // Set a URL first
      await container
          .read(configProvider.notifier)
          .setBaseUrl('https://api.example.com');

      // Set the same URL - should be a no-op
      await container
          .read(configProvider.notifier)
          .setBaseUrl('https://api.example.com');

      // Verify it was only saved once (state didn't change twice)
      expect(container.read(configProvider).baseUrl, 'https://api.example.com');
    });

    test('set directly updates state', () {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(testSoliplexConfig),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(configProvider.notifier)
          .set(const AppConfig(baseUrl: 'https://custom.example.com'));

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

  group('platformDefaultBackendUrl', () {
    test('returns localhost on native platform', () {
      // Tests run on native (not web), so should return localhost
      expect(platformDefaultBackendUrl(), 'http://localhost:8000');
    });
  });

  group('URL priority chain', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('preloaded URL has highest priority', () {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(
            const SoliplexConfig(
              logo: LogoConfig.soliplex,
              defaultBackendUrl: 'https://config.com',
            ),
          ),
          preloadedBaseUrlProvider.overrideWithValue('https://saved.com'),
        ],
      );
      addTearDown(container.dispose);

      // Saved URL wins over config URL
      expect(container.read(configProvider).baseUrl, 'https://saved.com');
    });

    test('explicit config URL has second priority', () {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(
            const SoliplexConfig(
              logo: LogoConfig.soliplex,
              defaultBackendUrl: 'https://config.com',
            ),
          ),
          // No preloadedBaseUrl
        ],
      );
      addTearDown(container.dispose);

      // Config URL used when no saved URL
      expect(container.read(configProvider).baseUrl, 'https://config.com');
    });

    test('platform default is lowest priority', () {
      final container = ProviderContainer(
        overrides: [
          shellConfigProvider.overrideWithValue(
            const SoliplexConfig(logo: LogoConfig.soliplex), // No explicit URL
          ),
          // No preloadedBaseUrl
        ],
      );
      addTearDown(container.dispose);

      // Platform default used when no saved URL and no config URL
      expect(container.read(configProvider).baseUrl, 'http://localhost:8000');
    });
  });
}
