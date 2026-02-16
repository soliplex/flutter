// ============================================================================
// API CONTRACT TESTS - soliplex_frontend
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
// ignore_for_file: unused_local_variable
// Redundant arguments are intentional - we test that parameters exist:
// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/soliplex_frontend.dart';

void main() {
  group('soliplex_frontend public API contract', () {
    group('Features', () {
      test('default constructor with all parameters', () {
        const features = Features(
          enableHttpInspector: true,
          enableQuizzes: true,
          enableSettings: true,
          showVersionInfo: true,
        );

        // Verify all properties are accessible
        expect(features.enableHttpInspector, isA<bool>());
        expect(features.enableQuizzes, isA<bool>());
        expect(features.enableSettings, isA<bool>());
        expect(features.showVersionInfo, isA<bool>());
      });

      test('minimal constructor', () {
        const features = Features.minimal();

        expect(features.enableHttpInspector, isFalse);
        expect(features.enableQuizzes, isFalse);
        expect(features.enableSettings, isFalse);
        expect(features.showVersionInfo, isFalse);
      });

      test('copyWith signature', () {
        const features = Features();
        final copied = features.copyWith(
          enableHttpInspector: false,
          enableQuizzes: false,
          enableSettings: false,
          showVersionInfo: false,
        );

        expect(copied, isA<Features>());
      });

      test('equality and hashCode', () {
        const a = Features();
        const b = Features();

        expect(a == b, isTrue);
        expect(a.hashCode, isA<int>());
      });

      test('toString', () {
        const features = Features();
        expect(features.toString(), isA<String>());
      });
    });

    group('RouteConfig', () {
      test('default constructor with all parameters', () {
        const config = RouteConfig(
          showHomeRoute: true,
          showRoomsRoute: true,
          initialRoute: '/',
        );

        // Verify all properties are accessible
        expect(config.showHomeRoute, isA<bool>());
        expect(config.showRoomsRoute, isA<bool>());
        expect(config.initialRoute, isA<String>());
      });

      test('copyWith signature', () {
        const config = RouteConfig();
        final copied = config.copyWith(
          showHomeRoute: false,
          showRoomsRoute: true,
          initialRoute: '/rooms',
        );

        expect(copied, isA<RouteConfig>());
      });

      test('equality and hashCode', () {
        const a = RouteConfig();
        const b = RouteConfig();

        expect(a == b, isTrue);
        expect(a.hashCode, isA<int>());
      });

      test('toString', () {
        const config = RouteConfig();
        expect(config.toString(), isA<String>());
      });
    });

    group('ThemeConfig', () {
      test('default constructor with all parameters', () {
        const config = ThemeConfig(
          colorConfig: ColorConfig(),
          fontConfig: FontConfig(bodyFont: 'Inter'),
        );

        // Verify all properties are accessible
        expect(config.colorConfig, isA<ColorConfig>());
        expect(config.fontConfig, isA<FontConfig>());
      });

      test('default values', () {
        const config = ThemeConfig();

        expect(config.colorConfig, isNull);
        expect(config.fontConfig, isNull);
      });

      test('copyWith signature', () {
        const config = ThemeConfig();
        final copied = config.copyWith(
          colorConfig: const ColorConfig(),
          fontConfig: const FontConfig(bodyFont: 'Inter'),
        );

        expect(copied, isA<ThemeConfig>());
      });

      test('copyWith can clear configs', () {
        const config = ThemeConfig(
          colorConfig: ColorConfig(),
          fontConfig: FontConfig(bodyFont: 'Inter'),
        );
        final cleared = config.copyWith(
          clearColorConfig: true,
          clearFontConfig: true,
        );

        expect(cleared.colorConfig, isNull);
        expect(cleared.fontConfig, isNull);
      });

      test('equality and hashCode', () {
        const a = ThemeConfig();
        const b = ThemeConfig();

        expect(a == b, isTrue);
        expect(a.hashCode, isA<int>());
      });

      test('toString', () {
        const config = ThemeConfig();
        expect(config.toString(), isA<String>());
      });
    });

    group('ColorPalette', () {
      test('constructor with all required parameters', () {
        const palette = ColorPalette(
          primary: Colors.blue,
          secondary: Colors.orange,
          background: Colors.white,
          foreground: Colors.black,
          muted: Color(0xFFE0E0E0),
          mutedForeground: Color(0xFF757575),
          border: Color(0xFFBDBDBD),
        );

        expect(palette.primary, isA<Color>());
        expect(palette.secondary, isA<Color>());
        expect(palette.background, isA<Color>());
        expect(palette.foreground, isA<Color>());
        expect(palette.muted, isA<Color>());
        expect(palette.mutedForeground, isA<Color>());
        expect(palette.border, isA<Color>());
      });

      test('optional fields are nullable', () {
        const palette = ColorPalette(
          primary: Colors.blue,
          secondary: Colors.orange,
          background: Colors.white,
          foreground: Colors.black,
          muted: Color(0xFFE0E0E0),
          mutedForeground: Color(0xFF757575),
          border: Color(0xFFBDBDBD),
        );

        expect(palette.tertiary, isA<Color?>());
        expect(palette.error, isA<Color?>());
        expect(palette.onPrimary, isA<Color?>());
        expect(palette.onSecondary, isA<Color?>());
        expect(palette.onTertiary, isA<Color?>());
        expect(palette.onError, isA<Color?>());
      });

      test('named constructors exist', () {
        const light = ColorPalette.defaultLight();
        const dark = ColorPalette.defaultDark();

        expect(light, isA<ColorPalette>());
        expect(dark, isA<ColorPalette>());
      });

      test('effective getters are accessible', () {
        const palette = ColorPalette.defaultLight();

        expect(palette.effectiveOnPrimary, isA<Color>());
        expect(palette.effectiveOnSecondary, isA<Color>());
        expect(palette.effectiveTertiary, isA<Color>());
        expect(palette.effectiveOnTertiary, isA<Color>());
        expect(palette.effectiveError, isA<Color>());
        expect(palette.effectiveOnError, isA<Color>());
      });

      test('copyWith signature', () {
        const palette = ColorPalette.defaultLight();
        final copied = palette.copyWith(
          primary: Colors.green,
          clearTertiary: true,
          clearError: true,
        );

        expect(copied, isA<ColorPalette>());
      });

      test('equality and hashCode', () {
        const a = ColorPalette.defaultLight();
        const b = ColorPalette.defaultLight();

        expect(a == b, isTrue);
        expect(a.hashCode, isA<int>());
      });

      test('toString', () {
        const palette = ColorPalette.defaultLight();
        expect(palette.toString(), isA<String>());
      });
    });

    group('ColorConfig', () {
      test('default constructor with palette parameters', () {
        const config = ColorConfig(
          light: ColorPalette.defaultLight(),
          dark: ColorPalette.defaultDark(),
        );

        expect(config.light, isA<ColorPalette>());
        expect(config.dark, isA<ColorPalette>());
      });

      test('default values use default palettes', () {
        const config = ColorConfig();

        expect(
          config.light,
          equals(const ColorPalette.defaultLight()),
        );
        expect(
          config.dark,
          equals(const ColorPalette.defaultDark()),
        );
      });

      test('copyWith signature', () {
        const config = ColorConfig();
        final copied = config.copyWith(
          light: const ColorPalette.defaultLight(),
          dark: const ColorPalette.defaultDark(),
        );

        expect(copied, isA<ColorConfig>());
      });

      test('equality and hashCode', () {
        const a = ColorConfig();
        const b = ColorConfig();

        expect(a == b, isTrue);
        expect(a.hashCode, isA<int>());
      });

      test('toString', () {
        const config = ColorConfig();
        expect(config.toString(), isA<String>());
      });
    });

    group('SoliplexConfig', () {
      test('default constructor with all parameters', () {
        const config = SoliplexConfig(
          logo: LogoConfig.soliplex,
          appName: 'TestApp',
          defaultBackendUrl: 'https://api.test.com',
          oauthRedirectScheme: 'com.test.app',
          features: Features(),
          theme: ThemeConfig(),
          routes: RouteConfig(),
          showLogoInAppBar: true,
          showAppNameInAppBar: false,
        );

        // Verify all properties are accessible
        expect(config.appName, isA<String>());
        expect(config.defaultBackendUrl, isA<String>());
        expect(config.oauthRedirectScheme, isA<String>());
        expect(config.features, isA<Features>());
        expect(config.theme, isA<ThemeConfig>());
        expect(config.routes, isA<RouteConfig>());
        expect(config.showLogoInAppBar, isA<bool>());
        expect(config.showAppNameInAppBar, isA<bool>());
      });

      test('copyWith signature', () {
        const config = SoliplexConfig(logo: LogoConfig.soliplex);
        final copied = config.copyWith(
          appName: 'NewApp',
          defaultBackendUrl: 'https://new.api.com',
          oauthRedirectScheme: 'com.new.app',
          features: const Features.minimal(),
          theme: const ThemeConfig(),
          routes: const RouteConfig(),
          showLogoInAppBar: true,
          showAppNameInAppBar: false,
        );

        expect(copied, isA<SoliplexConfig>());
      });

      test('equality and hashCode', () {
        const a = SoliplexConfig(logo: LogoConfig.soliplex);
        const b = SoliplexConfig(logo: LogoConfig.soliplex);

        expect(a == b, isTrue);
        expect(a.hashCode, isA<int>());
      });

      test('toString', () {
        const config = SoliplexConfig(logo: LogoConfig.soliplex);
        expect(config.toString(), isA<String>());
      });

      test('oauthRedirectScheme is nullable', () {
        // Null is valid - web doesn't need it, native validates at runtime
        const config = SoliplexConfig(logo: LogoConfig.soliplex);
        expect(config.oauthRedirectScheme, isNull);

        // Non-null is also valid
        const configWithScheme = SoliplexConfig(
          logo: LogoConfig.soliplex,
          oauthRedirectScheme: 'com.example.app',
        );
        expect(configWithScheme.oauthRedirectScheme, 'com.example.app');
      });

      test('showLogoInAppBar defaults to false', () {
        const config = SoliplexConfig(logo: LogoConfig.soliplex);
        expect(config.showLogoInAppBar, isFalse);
      });

      test('showAppNameInAppBar defaults to true', () {
        const config = SoliplexConfig(logo: LogoConfig.soliplex);
        expect(config.showAppNameInAppBar, isTrue);
      });
    });

    group('runSoliplexApp', () {
      test('function signature is correct', () {
        // Verify the function exists and has the expected signature.
        // We don't call it because it starts the app.
        // This test fails to compile if the signature changes.
        expect(
          runSoliplexApp,
          isA<Future<void> Function({required SoliplexConfig config})>(),
        );
      });
    });

    group('consumer simulation: white-label app configuration', () {
      test('typical white-label app setup', () {
        // Simulates how an external project would configure the app
        const config = SoliplexConfig(
          logo: LogoConfig(assetPath: 'assets/brand_logo.png'),
          appName: 'MyBrand',
          defaultBackendUrl: 'https://api.mybrand.com',
          oauthRedirectScheme: 'com.mybrand.app',
          features: Features(
            enableHttpInspector: false,
            enableQuizzes: true,
            enableSettings: true,
            showVersionInfo: false,
          ),
          theme: ThemeConfig(
            colorConfig: ColorConfig(
              light: ColorPalette(
                primary: Color(0xFF1976D2), // Brand blue
                secondary: Color(0xFF03DAC6),
                background: Color(0xFFFAFAFA),
                foreground: Color(0xFF1A1A1E),
                muted: Color(0xFFE4E4E8),
                mutedForeground: Color(0xFF6E6E78),
                border: Color(0xFFC8C8CE),
              ),
            ),
          ),
          routes: RouteConfig(
            showHomeRoute: false,
            showRoomsRoute: true,
            initialRoute: '/rooms',
          ),
        );

        expect(config.appName, equals('MyBrand'));
        expect(config.oauthRedirectScheme, equals('com.mybrand.app'));
        expect(config.features.enableHttpInspector, isFalse);
        expect(config.routes.initialRoute, equals('/rooms'));
      });

      test('minimal configuration with defaults', () {
        // External project using all defaults except logo (which is required)
        const config = SoliplexConfig(logo: LogoConfig.soliplex);

        expect(config.appName, equals('Soliplex'));
        // Defaults to localhost:8000. Used on native and web localhost.
        // On web production, origin is used instead (ignoring this value).
        expect(config.defaultBackendUrl, 'http://localhost:8000');
        // null requires explicit override for native platforms
        expect(config.oauthRedirectScheme, isNull);
        expect(config.features.enableHttpInspector, isTrue);
        expect(config.routes.showHomeRoute, isTrue);
      });

      test('custom theme colors with full branding', () {
        // External project with custom brand colors
        const config = SoliplexConfig(
          logo: LogoConfig.soliplex,
          theme: ThemeConfig(
            colorConfig: ColorConfig(
              light: ColorPalette(
                primary: Color(0xFF6200EE), // Purple brand
                secondary: Color(0xFF03DAC6), // Teal accent
                background: Color(0xFFFAFAFA),
                foreground: Color(0xFF1A1A1E),
                muted: Color(0xFFE4E4E8),
                mutedForeground: Color(0xFF6E6E78),
                border: Color(0xFFC8C8CE),
                error: Color(0xFFB00020), // Custom error red
              ),
            ),
          ),
        );

        expect(
          config.theme.colorConfig?.light.primary,
          equals(const Color(0xFF6200EE)),
        );
      });
    });
  });
}
