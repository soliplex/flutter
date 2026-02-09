import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/core/logging/log_config.dart';
import 'package:soliplex_frontend/core/logging/logging_provider.dart';
import 'package:soliplex_frontend/core/providers/connectivity_provider.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
import 'package:soliplex_frontend/features/settings/telemetry_screen.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

import '../../helpers/test_helpers.dart';

class _TestLogConfigNotifier extends LogConfigNotifier {
  _TestLogConfigNotifier({LogConfig? initial})
      : _config = initial ?? LogConfig.defaultConfig;

  final LogConfig _config;
  bool setBackendLoggingEnabledCalled = false;
  bool? lastBackendEnabledValue;

  @override
  LogConfig build() => _config;

  @override
  Future<void> setBackendLoggingEnabled({required bool enabled}) async {
    setBackendLoggingEnabledCalled = true;
    lastBackendEnabledValue = enabled;
    state = state.copyWith(backendLoggingEnabled: enabled);
  }

  @override
  Future<void> setBackendEndpoint(String endpoint) async {
    state = state.copyWith(backendEndpoint: endpoint);
  }

  @override
  Future<void> setMinimumLevel(LogLevel level) async {
    state = state.copyWith(minimumLevel: level);
  }

  @override
  Future<void> setConsoleLoggingEnabled({required bool enabled}) async {
    state = state.copyWith(consoleLoggingEnabled: enabled);
  }

  @override
  Future<void> setStdoutLoggingEnabled({required bool enabled}) async {
    state = state.copyWith(stdoutLoggingEnabled: enabled);
  }
}

Widget _createTelemetryApp({
  LogConfig? config,
  AsyncValue<List<ConnectivityResult>>? connectivity,
  void Function(_TestLogConfigNotifier)? onNotifierCreated,
}) {
  return UncontrolledProviderScope(
    container: ProviderContainer(
      overrides: [
        shellConfigProvider.overrideWithValue(testSoliplexConfig),
        logConfigProvider.overrideWith(() {
          final notifier = _TestLogConfigNotifier(initial: config);
          onNotifierCreated?.call(notifier);
          return notifier;
        }),
        if (connectivity != null)
          connectivityProvider.overrideWithValue(connectivity),
      ],
    ),
    child: MaterialApp(
      theme: testThemeData,
      home: const Scaffold(body: TelemetryScreen()),
    ),
  );
}

void main() {
  group('TelemetryScreen', () {
    group('Backend Logging toggle', () {
      testWidgets('displays toggle in off state by default', (tester) async {
        await tester.pumpWidget(_createTelemetryApp());
        await tester.pump();

        expect(find.text('Backend Logging'), findsOneWidget);
        expect(
          find.text('Ship logs to the backend for analysis'),
          findsOneWidget,
        );

        final switchWidget = tester.widget<SwitchListTile>(
          find.byType(SwitchListTile),
        );
        expect(switchWidget.value, isFalse);
      });

      testWidgets('displays toggle in on state when enabled', (tester) async {
        await tester.pumpWidget(
          _createTelemetryApp(
            config: LogConfig.defaultConfig.copyWith(
              backendLoggingEnabled: true,
            ),
          ),
        );
        await tester.pump();

        final switchWidget = tester.widget<SwitchListTile>(
          find.byType(SwitchListTile),
        );
        expect(switchWidget.value, isTrue);
      });

      testWidgets('toggle calls setBackendLoggingEnabled', (tester) async {
        late _TestLogConfigNotifier notifier;

        await tester.pumpWidget(
          _createTelemetryApp(
            onNotifierCreated: (n) => notifier = n,
          ),
        );
        await tester.pump();

        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();

        expect(notifier.setBackendLoggingEnabledCalled, isTrue);
        expect(notifier.lastBackendEnabledValue, isTrue);
      });
    });

    group('Endpoint display', () {
      testWidgets('shows default endpoint', (tester) async {
        await tester.pumpWidget(_createTelemetryApp());
        await tester.pump();

        expect(find.text('Endpoint'), findsOneWidget);
        expect(
          find.text(LogConfig.defaultConfig.backendEndpoint),
          findsOneWidget,
        );
      });

      testWidgets('shows custom endpoint from config', (tester) async {
        await tester.pumpWidget(
          _createTelemetryApp(
            config: LogConfig.defaultConfig.copyWith(
              backendEndpoint: '/custom/logs',
            ),
          ),
        );
        await tester.pump();

        expect(find.text('/custom/logs'), findsOneWidget);
      });
    });

    group('Connection Status', () {
      testWidgets('shows wifi connectivity', (tester) async {
        await tester.pumpWidget(
          _createTelemetryApp(
            connectivity: const AsyncValue.data([ConnectivityResult.wifi]),
          ),
        );
        await tester.pump();

        expect(find.text('Connection Status'), findsOneWidget);
        expect(find.text('wifi'), findsOneWidget);
        expect(find.byIcon(Icons.cloud_done), findsOneWidget);
      });

      testWidgets('shows no connection state', (tester) async {
        await tester.pumpWidget(
          _createTelemetryApp(
            connectivity: const AsyncValue.data([ConnectivityResult.none]),
          ),
        );
        await tester.pump();

        expect(find.text('No connection'), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      });

      testWidgets('shows loading state', (tester) async {
        await tester.pumpWidget(
          _createTelemetryApp(
            connectivity: const AsyncValue<List<ConnectivityResult>>.loading(),
          ),
        );
        await tester.pump();

        expect(find.text('Checking...'), findsOneWidget);
        expect(find.byIcon(Icons.cloud_queue), findsOneWidget);
      });

      testWidgets('shows error state', (tester) async {
        await tester.pumpWidget(
          _createTelemetryApp(
            connectivity: AsyncValue<List<ConnectivityResult>>.error(
              Exception('fail'),
              StackTrace.empty,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Unknown'), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      });

      testWidgets('shows multiple connectivity types', (tester) async {
        await tester.pumpWidget(
          _createTelemetryApp(
            connectivity: const AsyncValue.data([
              ConnectivityResult.wifi,
              ConnectivityResult.vpn,
            ]),
          ),
        );
        await tester.pump();

        expect(find.text('wifi, vpn'), findsOneWidget);
      });
    });
  });
}
