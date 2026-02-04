import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/logging/loggers.dart';
import 'package:soliplex_frontend/core/logging/logging_provider.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
import 'package:soliplex_frontend/core/router/app_router.dart';
import 'package:soliplex_frontend/design/theme/theme.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Root application widget.
///
/// Handles app-level concerns including lifecycle-aware wakelock management.
class SoliplexApp extends ConsumerStatefulWidget {
  const SoliplexApp({super.key});

  @override
  ConsumerState<SoliplexApp> createState() => _SoliplexAppState();
}

class _SoliplexAppState extends ConsumerState<SoliplexApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableWakelock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enableWakelock();
    }
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      Loggers.config.warning('Failed to enable wake lock: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize logging system (creates sinks and applies config).
    ref.watch(logConfigControllerProvider);

    final authState = ref.watch(authProvider);
    final shellConfig = ref.watch(shellConfigProvider);
    final themeConfig = shellConfig.theme;

    final lightTheme = soliplexLightTheme(colors: themeConfig.lightColors);
    final darkTheme = soliplexDarkTheme(colors: themeConfig.darkColors);

    // Don't construct routing until auth state is resolved.
    // This prevents building route widgets that would be discarded,
    // avoiding wasted work and premature provider side effects.
    if (authState is AuthLoading) {
      return MaterialApp(
        title: shellConfig.appName,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        home: const _AuthLoadingScreen(),
      );
    }

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: shellConfig.appName,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Loading screen shown while auth session is being restored.
class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}
