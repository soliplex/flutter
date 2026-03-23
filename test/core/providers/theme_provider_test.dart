import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_frontend/core/providers/theme_provider.dart';

void main() {
  group('ThemeModeNotifier', () {
    setUp(() {
      resetPreloadedThemeMode();
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to ThemeMode.system when no preference saved', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('toggle from system (light) switches to dark', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.notifier).toggle(Brightness.light);

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('toggle from system (dark) switches to light', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.notifier).toggle(Brightness.dark);

      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('toggle from dark switches to light', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      await initializeTheme();

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Force state to dark (since preloaded value is cached)
      await container.read(themeModeProvider.notifier).toggle(Brightness.dark);
      // Now it should be light
      expect(container.read(themeModeProvider), ThemeMode.light);

      // Toggle again - from light to dark
      await container.read(themeModeProvider.notifier).toggle(Brightness.light);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('toggle from light switches to dark', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // First toggle from system (assuming light) to dark
      await container.read(themeModeProvider.notifier).toggle(Brightness.light);
      expect(container.read(themeModeProvider), ThemeMode.dark);

      // Toggle from dark to light
      await container.read(themeModeProvider.notifier).toggle(Brightness.light);
      expect(container.read(themeModeProvider), ThemeMode.light);

      // Toggle from light to dark
      await container.read(themeModeProvider.notifier).toggle(Brightness.light);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('persists theme preference to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.notifier).toggle(Brightness.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });
  });

  group('initializeTheme', () {
    setUp(() {
      resetPreloadedThemeMode();
      SharedPreferences.setMockInitialValues({});
    });

    test('loads saved light preference', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      await initializeTheme();

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('loads saved dark preference', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      await initializeTheme();

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('defaults to system when no preference saved', () async {
      SharedPreferences.setMockInitialValues({});
      await initializeTheme();

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('defaults to system when invalid preference saved', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'invalid'});
      await initializeTheme();

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);
    });
  });
}
