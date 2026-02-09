import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_frontend/core/logging/logging_provider.dart';
import 'package:soliplex_frontend/core/providers/connectivity_provider.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Creates a container with pre-loaded prefs for synchronous config loading.
  ProviderContainer createContainer(SharedPreferences preloadedPrefs) {
    return ProviderContainer(
      overrides: [
        preloadedPrefsProvider.overrideWithValue(preloadedPrefs),
        connectivityProvider.overrideWith(
          (ref) => Stream.value([ConnectivityResult.wifi]),
        ),
      ],
    );
  }

  group('installIdProvider', () {
    test('generates and persists install ID', () {
      final container = createContainer(prefs);
      addTearDown(container.dispose);

      final id = container.read(installIdProvider);

      expect(id, isNotEmpty);
      // Verify it's persisted.
      expect(prefs.getString('install_id'), id);
    });

    test('returns same ID across reads', () {
      final container = createContainer(prefs);
      addTearDown(container.dispose);

      final id1 = container.read(installIdProvider);
      final id2 = container.read(installIdProvider);

      expect(id1, equals(id2));
    });

    test('returns existing ID from prefs', () async {
      SharedPreferences.setMockInitialValues({
        'install_id': 'existing-uuid',
      });
      prefs = await SharedPreferences.getInstance();

      final container = createContainer(prefs);
      addTearDown(container.dispose);

      final id = container.read(installIdProvider);
      expect(id, 'existing-uuid');
    });
  });

  group('sessionIdProvider', () {
    test('generates a non-empty session ID', () {
      final container = createContainer(prefs);
      addTearDown(container.dispose);

      final id = container.read(sessionIdProvider);

      expect(id, isNotEmpty);
    });

    test('returns same ID within same container', () {
      final container = createContainer(prefs);
      addTearDown(container.dispose);

      final id1 = container.read(sessionIdProvider);
      final id2 = container.read(sessionIdProvider);

      expect(id1, equals(id2));
    });
  });
}
