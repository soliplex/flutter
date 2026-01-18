/// Example of creating a white-label application using Soliplex Frontend.
///
/// This example demonstrates how to customize the app shell with:
/// - Custom app name and branding
/// - Feature flags to disable unwanted features
/// - Custom theme colors
/// - Custom routes via a registry
library example;

import 'package:flutter/material.dart';
import 'package:soliplex_frontend/soliplex_frontend.dart';

/// Custom brand colors for the white-label app (indigo theme).
const _customLightColors = SoliplexColors(
  background: Color(0xFFF8FAFC),
  foreground: Color(0xFF1E293B),
  primary: Color(0xFF6366F1), // Indigo
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFFEEF2FF),
  onSecondary: Color(0xFF4338CA),
  accent: Color(0xFFE0E7FF),
  onAccent: Color(0xFF4338CA),
  muted: Color(0xFFF1F5F9),
  mutedForeground: Color(0xFF64748B),
  destructive: Color(0xFFEF4444),
  onDestructive: Color(0xFFFFFFFF),
  border: Color(0x1A6366F1),
  inputBackground: Color(0xFFF1F5F9),
  hintText: Color(0xFF94A3B8),
);

/// Custom dark colors for the white-label app.
const _customDarkColors = SoliplexColors(
  background: Color(0xFF0F172A),
  foreground: Color(0xFFF1F5F9),
  primary: Color(0xFF818CF8), // Lighter indigo for dark mode
  onPrimary: Color(0xFF1E1B4B),
  secondary: Color(0xFF1E293B),
  onSecondary: Color(0xFFC7D2FE),
  accent: Color(0xFF1E293B),
  onAccent: Color(0xFFC7D2FE),
  muted: Color(0xFF334155),
  mutedForeground: Color(0xFF94A3B8),
  destructive: Color(0xFFF87171),
  onDestructive: Color(0xFF7F1D1D),
  border: Color(0xFF334155),
  inputBackground: Color(0xFF1E293B),
  hintText: Color(0xFF64748B),
);

/// Example custom registry that adds a custom route.
class MyBrandRegistry implements SoliplexRegistry {
  const MyBrandRegistry();

  @override
  List<PanelDefinition> get panels => const [];

  @override
  List<CommandDefinition> get commands => const [];

  @override
  List<RouteDefinition> get routes => [
        RouteDefinition(
          path: '/about',
          builder: (context, params) => const AboutScreen(),
        ),
      ];
}

/// Example custom screen added via the registry.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About MyBrand')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 64),
            SizedBox(height: 16),
            Text('MyBrand AI Assistant'),
            Text('Powered by Soliplex'),
          ],
        ),
      ),
    );
  }
}

void main() {
  runSoliplexApp(
    config: const SoliplexConfig(
      appName: 'MyBrand AI',
      defaultBackendUrl: 'https://api.mybrand.example.com',
      features: Features(
        // Disable the HTTP inspector in production
        enableHttpInspector: false,
      ),
      theme: ThemeConfig(
        lightColors: _customLightColors,
        darkColors: _customDarkColors,
      ),
    ),
    registry: const MyBrandRegistry(),
  );
}
