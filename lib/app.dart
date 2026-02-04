import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/auth/auth_provider.dart';
import 'package:soliplex_frontend/core/auth/auth_state.dart';
import 'package:soliplex_frontend/core/logging/logging_provider.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
import 'package:soliplex_frontend/core/router/app_router.dart';
import 'package:soliplex_frontend/design/theme/theme.dart';

/// Root application widget.
class SoliplexApp extends ConsumerWidget {
  const SoliplexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize logging sinks (must be watched to activate the providers).
    ref
      ..watch(consoleSinkProvider)
      ..watch(stdoutSinkProvider);

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
