# Soliplex Flutter

[![Flutter CI](https://github.com/soliplex/flutter/actions/workflows/flutter.yaml/badge.svg)](https://github.com/soliplex/flutter/actions/workflows/flutter.yaml)

Flutter frontend for Soliplex RAG platform.

## White-Label Usage

Soliplex Frontend can be used as a white-label solution for building custom
AI chat applications. Import the library and configure your branded app:

```dart
import 'package:soliplex_frontend/soliplex_frontend.dart';

void main() {
  runSoliplexApp(
    config: SoliplexConfig(
      appName: 'MyBrand AI',
      defaultBackendUrl: 'https://api.mybrand.example.com',
      features: Features(
        enableHttpInspector: false, // Disable in production
        enableQuizzes: true,
        enableSettings: true,
      ),
      theme: ThemeConfig(
        lightColors: myCustomLightColors,
        darkColors: myCustomDarkColors,
      ),
    ),
  );
}
```

### Configuration Options

- **SoliplexConfig**: Main configuration class
  - `appName`: Display name for your application
  - `defaultBackendUrl`: Your Soliplex backend URL
  - `features`: Feature flags to enable/disable features
  - `theme`: Custom color schemes
  - `routes`: Route visibility configuration

- **Features**: Toggle app features
  - `enableHttpInspector`: Show/hide HTTP traffic inspector (dev tool)
  - `enableQuizzes`: Show/hide quiz functionality
  - `enableSettings`: Show/hide settings screen
  - `showVersionInfo`: Show/hide version info

- **SoliplexRegistry**: Add custom extensions
  - `panels`: Custom side panels
  - `commands`: Slash commands
  - `routes`: Additional routes

See `example/main.dart` for a complete white-label example with custom colors
and a custom route.

## Development

```bash
flutter pub get
flutter run -d chrome --web-port 59001
```

## Testing

```bash
flutter test
```

## Related

- [Soliplex Backend](https://github.com/soliplex/soliplex)
- [Documentation](https://soliplex.github.io/)
