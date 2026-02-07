import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soliplex_frontend/core/logging/log_config.dart';
import 'package:soliplex_frontend/core/logging/logging_provider.dart';
import 'package:soliplex_frontend/features/settings/telemetry_screen.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildScreen({
    LogConfig? config,
    AsyncValue<List<ConnectivityResult>>? connectivity,
  }) {
    final effectiveConfig = config ?? LogConfig.defaultConfig;
    return createTestApp(
      home: const TelemetryScreen(),
      overrides: [
        preloadedPrefsProvider.overrideWithValue(prefs),
        logConfigProvider.overrideWith(() {
          return _MockLogConfigNotifier(effectiveConfig);
        }),
        connectivityProvider.overrideWithValue(
          connectivity ?? const AsyncValue.data([ConnectivityResult.wifi]),
        ),
      ],
    );
  }

  group('TelemetryScreen', () {
    testWidgets('shows toggle in off state by default', (tester) async {
      await tester.pumpWidget(buildScreen());

      final switchFinder = find.byType(SwitchListTile);
      expect(switchFinder, findsOneWidget);

      final switchTile = tester.widget<SwitchListTile>(switchFinder);
      expect(switchTile.value, isFalse);
      expect(find.text('Backend Logging'), findsOneWidget);
    });

    testWidgets('shows toggle in on state when enabled', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          config: LogConfig.defaultConfig.copyWith(
            backendLoggingEnabled: true,
          ),
        ),
      );

      final switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchTile.value, isTrue);
    });

    testWidgets('displays endpoint path', (tester) async {
      await tester.pumpWidget(buildScreen());

      expect(find.text('/api/v1/logs'), findsOneWidget);
      expect(find.text('Endpoint'), findsOneWidget);
    });

    testWidgets('displays custom endpoint', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          config: LogConfig.defaultConfig.copyWith(
            backendEndpoint: '/custom/endpoint',
          ),
        ),
      );

      expect(find.text('/custom/endpoint'), findsOneWidget);
    });

    testWidgets('shows connected status for wifi', (tester) async {
      await tester.pumpWidget(buildScreen());

      expect(find.text('Connection Status'), findsOneWidget);
      expect(find.text('wifi'), findsOneWidget);
    });

    testWidgets('shows no connection status', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          connectivity: const AsyncValue.data([ConnectivityResult.none]),
        ),
      );

      expect(find.text('No connection'), findsOneWidget);
    });

    testWidgets('shows loading connectivity status', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          connectivity: const AsyncValue.loading(),
        ),
      );

      expect(find.text('Checking...'), findsOneWidget);
    });

    testWidgets('shows error connectivity status', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          connectivity: AsyncValue.error(
            Exception('fail'),
            StackTrace.current,
          ),
        ),
      );

      expect(find.text('Unknown'), findsOneWidget);
    });
  });
}

class _MockLogConfigNotifier extends LogConfigNotifier {
  _MockLogConfigNotifier(this._config);

  final LogConfig _config;

  @override
  LogConfig build() => _config;
}
