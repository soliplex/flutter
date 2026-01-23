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
          lightColors: lightSoliplexColors,
          darkColors: darkSoliplexColors,
        );

        // Verify all properties are accessible
        expect(config.lightColors, isA<SoliplexColors>());
        expect(config.darkColors, isA<SoliplexColors>());
      });

      test('copyWith signature', () {
        const config = ThemeConfig();
        final copied = config.copyWith(
          lightColors: lightSoliplexColors,
          darkColors: darkSoliplexColors,
        );

        expect(copied, isA<ThemeConfig>());
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

    group('SoliplexColors', () {
      test('constructor with all required parameters', () {
        const colors = SoliplexColors(
          background: Colors.white,
          foreground: Colors.black,
          primary: Colors.blue,
          onPrimary: Colors.white,
          secondary: Colors.grey,
          onSecondary: Colors.black,
          accent: Colors.amber,
          onAccent: Colors.black,
          muted: Colors.grey,
          mutedForeground: Colors.grey,
          destructive: Colors.red,
          onDestructive: Colors.white,
          border: Colors.grey,
          inputBackground: Colors.white,
          hintText: Colors.grey,
        );

        // Verify all 15 color properties are accessible
        expect(colors.background, isA<Color>());
        expect(colors.foreground, isA<Color>());
        expect(colors.primary, isA<Color>());
        expect(colors.onPrimary, isA<Color>());
        expect(colors.secondary, isA<Color>());
        expect(colors.onSecondary, isA<Color>());
        expect(colors.accent, isA<Color>());
        expect(colors.onAccent, isA<Color>());
        expect(colors.muted, isA<Color>());
        expect(colors.mutedForeground, isA<Color>());
        expect(colors.destructive, isA<Color>());
        expect(colors.onDestructive, isA<Color>());
        expect(colors.border, isA<Color>());
        expect(colors.inputBackground, isA<Color>());
        expect(colors.hintText, isA<Color>());
      });

      test('lightSoliplexColors constant is accessible', () {
        expect(lightSoliplexColors, isA<SoliplexColors>());
        expect(lightSoliplexColors.background, isA<Color>());
      });

      test('darkSoliplexColors constant is accessible', () {
        expect(darkSoliplexColors, isA<SoliplexColors>());
        expect(darkSoliplexColors.background, isA<Color>());
      });
    });

    group('SoliplexConfig', () {
      test('default constructor with all parameters', () {
        const config = SoliplexConfig(
          appName: 'TestApp',
          defaultBackendUrl: 'https://api.test.com',
          oauthRedirectScheme: 'com.test.app',
          features: Features(),
          theme: ThemeConfig(),
          routes: RouteConfig(),
        );

        // Verify all properties are accessible
        expect(config.appName, isA<String>());
        expect(config.defaultBackendUrl, isA<String>());
        expect(config.oauthRedirectScheme, isA<String>());
        expect(config.features, isA<Features>());
        expect(config.theme, isA<ThemeConfig>());
        expect(config.routes, isA<RouteConfig>());
      });

      test('copyWith signature', () {
        const config = SoliplexConfig();
        final copied = config.copyWith(
          appName: 'NewApp',
          defaultBackendUrl: 'https://new.api.com',
          oauthRedirectScheme: 'com.new.app',
          features: const Features.minimal(),
          theme: const ThemeConfig(),
          routes: const RouteConfig(),
        );

        expect(copied, isA<SoliplexConfig>());
      });

      test('equality and hashCode', () {
        const a = SoliplexConfig();
        const b = SoliplexConfig();

        expect(a == b, isTrue);
        expect(a.hashCode, isA<int>());
      });

      test('toString', () {
        const config = SoliplexConfig();
        expect(config.toString(), isA<String>());
      });

      test('oauthRedirectScheme is nullable', () {
        // Null is valid - web doesn't need it, native validates at runtime
        const config = SoliplexConfig();
        expect(config.oauthRedirectScheme, isNull);

        // Non-null is also valid
        const configWithScheme = SoliplexConfig(
          oauthRedirectScheme: 'com.example.app',
        );
        expect(configWithScheme.oauthRedirectScheme, 'com.example.app');
      });
    });

    group('runSoliplexApp', () {
      test('function signature is correct', () {
        // Verify the function exists and has the expected signature.
        // We don't call it because it starts the app.
        // This test fails to compile if the signature changes.
        expect(
          runSoliplexApp,
          isA<Future<void> Function({SoliplexConfig config})>(),
        );
      });
    });

    group('consumer simulation: white-label app configuration', () {
      test('typical white-label app setup', () {
        // Simulates how an external project would configure the app
        const config = SoliplexConfig(
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
            lightColors: lightSoliplexColors,
            darkColors: darkSoliplexColors,
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
        // External project using all defaults
        const config = SoliplexConfig();

        expect(config.appName, equals('Soliplex'));
        // null means "use platform default" (localhost on native, origin on
        // web). Resolved at runtime by ConfigNotifier.
        expect(config.defaultBackendUrl, isNull);
        // null requires explicit override for native platforms
        expect(config.oauthRedirectScheme, isNull);
        expect(config.features.enableHttpInspector, isTrue);
        expect(config.routes.showHomeRoute, isTrue);
      });

      test('custom theme colors', () {
        // External project with custom branding
        const customLightColors = SoliplexColors(
          background: Color(0xFFFFFFFF),
          foreground: Color(0xFF000000),
          primary: Color(0xFF6200EE),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF03DAC6),
          onSecondary: Color(0xFF000000),
          accent: Color(0xFFBB86FC),
          onAccent: Color(0xFF000000),
          muted: Color(0xFFE0E0E0),
          mutedForeground: Color(0xFF757575),
          destructive: Color(0xFFB00020),
          onDestructive: Color(0xFFFFFFFF),
          border: Color(0xFFBDBDBD),
          inputBackground: Color(0xFFF5F5F5),
          hintText: Color(0xFF9E9E9E),
        );

        const config = SoliplexConfig(
          theme: ThemeConfig(lightColors: customLightColors),
        );

        expect(
          config.theme.lightColors.primary,
          equals(const Color(0xFF6200EE)),
        );
      });
    });
  });
}
