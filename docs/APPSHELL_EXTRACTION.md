# AppShell Extraction Branch

Branch: `feat/appshell-extraction`

This branch extracts the Soliplex Flutter app into a reusable white-label shell
that external teams can customize with their own branding, features, and backend.

## What This Branch Does

### Before (main branch)

The Soliplex app was a monolithic Flutter application with hardcoded:

- App name ("Soliplex")
- Backend URL (`https://api.soliplex.ai`)
- Theme colors
- Feature availability
- Global state scattered throughout

### After (this branch)

The app is now a **configurable shell** that:

1. Exports a single entry point: `runSoliplexApp(config: SoliplexConfig(...))`
2. Accepts all customization via `SoliplexConfig`
3. Uses no global state - configuration flows through Riverpod providers
4. Can be imported as a package dependency

## Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                     White-Label App (e.g., ACME Box)            │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  main.dart                                                 │  │
│  │    runSoliplexApp(config: SoliplexConfig(...))            │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  soliplex_frontend (this package)                         │  │
│  │    - SoliplexConfig (branding, features, theme, routes)   │  │
│  │    - SoliplexApp (MaterialApp + router)                   │  │
│  │    - All screens, widgets, providers                      │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  soliplex_client (pure Dart)                              │  │
│  │    - REST API client                                       │  │
│  │    - AG-UI protocol                                        │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Configuration Options

### SoliplexConfig

```dart
const config = SoliplexConfig(
  appName: 'ACME Box',                           // Display name
  defaultBackendUrl: 'https://api.acme.com',     // API endpoint
  features: Features(...),                        // Feature flags
  theme: ThemeConfig(...),                        // Custom colors
  routes: RouteConfig(...),                       // Navigation
);
```

### Features

| Flag                 | Default | Description                        |
|----------------------|---------|-----------------------------------|
| `enableHttpInspector` | `true`  | Show HTTP traffic inspector        |
| `enableQuizzes`       | `true`  | Enable quiz feature               |
| `enableSettings`      | `true`  | Show settings screen              |
| `showVersionInfo`     | `true`  | Display version in settings       |

### ThemeConfig

```dart
ThemeConfig(
  lightColors: SoliplexColors(
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF000000),
    primary: Color(0xFF6200EE),
    // ... 15 color tokens total
  ),
  darkColors: SoliplexColors(...),
)
```

### RouteConfig

```dart
RouteConfig(
  showHomeRoute: true,      // Show home/connect screen
  showRoomsRoute: true,     // Show rooms list
  initialRoute: '/rooms',   // Starting route
)
```

## File Organization

```text
lib/
├── soliplex_frontend.dart      # Public API exports
├── run_soliplex_app.dart       # Entry point function
├── app.dart                    # SoliplexApp widget
├── core/
│   ├── models/
│   │   ├── soliplex_config.dart   # Root config
│   │   ├── features.dart          # Feature flags
│   │   ├── theme_config.dart      # Theme wrapper
│   │   └── route_config.dart      # Navigation config
│   ├── providers/
│   │   ├── shell_config_provider.dart  # Injected config
│   │   └── config_provider.dart        # Runtime state
│   └── router/
│       └── app_router.dart        # GoRouter setup
├── design/
│   └── tokens/
│       └── colors.dart            # SoliplexColors
└── features/                      # Screen implementations
```

## Testing with Whitelabel

The [soliplex/whitelabel](https://github.com/soliplex/whitelabel) repository
provides an example white-label app that consumes this package.

### Local Development Setup

1. Clone both repositories side-by-side:

   ```bash
   cd ~/dev
   git clone https://github.com/soliplex/flutter.git soliplex-flutter
   git clone https://github.com/soliplex/whitelabel.git whitelabel
   ```

2. Checkout the appshell branch:

   ```bash
   cd soliplex-flutter
   git checkout feat/appshell-extraction
   ```

3. Configure whitelabel to use local path:

   ```yaml
   # ~/dev/whitelabel/pubspec.yaml
   dependencies:
     soliplex_frontend:
       path: ../soliplex-flutter
   ```

4. Run the whitelabel app:

   ```bash
   cd ~/dev/whitelabel
   flutter pub get
   flutter run -d macos   # or -d chrome --web-port 59003
   ```

### Running Integration Tests

Integration tests require a running Soliplex backend:

```bash
# Terminal 1: Start backend
cd ~/path/to/soliplex-backend
soliplex-cli serve example/minimal.yaml --no-auth-mode

# Terminal 2: Run integration tests
cd ~/dev/soliplex-flutter
SOLIPLEX_BACKEND_URL=http://localhost:8000 \
  flutter test integration_tests/ -d macos
```

### Verifying White-Label Customization

1. **Custom branding**: The whitelabel app shows "ACME Box" in titles
2. **Custom colors**: Uses DOS-green terminal theme
3. **Feature flags**: HTTP inspector disabled
4. **Backend URL**: Points to custom API endpoint

### Testing Configuration Changes

Edit `~/dev/whitelabel/lib/main.dart`:

```dart
runSoliplexApp(
  config: const SoliplexConfig(
    appName: 'Test Brand',
    defaultBackendUrl: 'http://localhost:8000',
    features: Features(
      enableHttpInspector: true,  // Enable for debugging
      enableQuizzes: false,       // Disable quizzes
    ),
  ),
);
```

Hot reload preserves the config changes.

## Key Commits

| Commit | Description |
|--------|-------------|
| `1d888e0` | Initial extraction - `runSoliplexApp`, `SoliplexConfig` |
| `a54e81b` | Remove global state from shell config provider |
| `9b1d81d` | Wire `defaultBackendUrl`, remove remaining global state |
| `f0c22a0` | Simplify route config, enhance router tests |

## Production Deployment

For production, switch to git dependency:

```yaml
# pubspec.yaml
dependencies:
  soliplex_frontend:
    git:
      url: https://github.com/soliplex/flutter.git
      ref: feat/appshell-extraction  # or main after merge
```

## What's NOT Included

This branch focuses on the shell extraction. The following are out of scope:

- Documentation generation (dartdoc)
- Example app within this repo
- Registry pattern for runtime customization
- Plugin architecture

These may be added in future iterations.
