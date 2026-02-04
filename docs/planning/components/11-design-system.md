# 11 - Design System

## Overview

Token-based design system providing colors, typography, spacing, radii, and breakpoints.
Uses Flutter's ThemeExtension pattern for custom tokens and supports white-label
theming through dependency injection of color palettes.

## Files

| File | Purpose |
|------|---------|
| `lib/design/design.dart` | Barrel export facade |
| `lib/design/color/color_scheme_extensions.dart` | Semantic color getters |
| `lib/design/theme/theme.dart` | Theme factory functions |
| `lib/design/theme/theme_extensions.dart` | Custom ThemeExtension |
| `lib/design/tokens/breakpoints.dart` | Layout breakpoint constants |
| `lib/design/tokens/colors.dart` | Color palette definitions |
| `lib/design/tokens/radii.dart` | Border radius tokens |
| `lib/design/tokens/spacing.dart` | Grid spacing constants |
| `lib/design/tokens/typography.dart` | TextTheme factory |
| `lib/design/tokens/typography_x.dart` | Monospace font helpers |

## Public API

### Tokens

**`SoliplexBreakpoints`** - Layout breakpoint constants

- `desktop`, `tablet`, `mobile`

**`SoliplexColors`** - Semantic color palette

- Background, foreground, primary, destructive, etc.
- `lightSoliplexColors`, `darkSoliplexColors` - Default palettes

**`SoliplexRadii`** - Border radius tokens

- `sm`, `md`, `lg`, `xl`
- Includes `lerp` for animation support
- `soliplexRadii` - Default values

**`SoliplexSpacing`** - Grid spacing constants

- `s1` through `s6`

### Theme Configuration

**`soliplexLightTheme({SoliplexColors})`** - Light ThemeData factory

**`soliplexDarkTheme({SoliplexColors})`** - Dark ThemeData factory

**`soliplexTextTheme(SoliplexColors)`** - TextTheme factory

### Extensions

**`SymbolicColors`** - Extension on `ColorScheme`

- `info`, `warning`, `danger`, `success` getters adapting to brightness

**`SoliplexTheme`** - ThemeExtension for custom tokens

- `colors`, `radii`, `badgeTheme`
- `SoliplexTheme.of(context)` accessor

**`TypographyX`** - Extension on `BuildContext`

- `context.monospace` - Platform-specific monospace styles

## Dependencies

### External Packages

- `flutter/material.dart` - Core theme types
- `dart:ui` - lerpDouble for radii

### Internal Dependencies

| Domain | Imports |
|--------|---------|
| Shared | `platform_resolver` (for typography) |

## Initialization Flow

```text
1. Token Definition: Primitives defined as constants in tokens/
2. Theme Construction:
   ├─ App calls soliplexLightTheme() or soliplexDarkTheme()
   └─ Optional SoliplexColors for white-labeling
3. Mapping:
   ├─ SoliplexColors → Material ColorScheme
   └─ Component themes configured with spacing/radii
4. Extension Injection:
   └─ Custom tokens wrapped in SoliplexTheme → ThemeData.extensions
5. Consumption:
   ├─ Standard: Theme.of(context)
   └─ Custom: SoliplexTheme.of(context), context.monospace
```

## Architectural Patterns

### Token-Based Design

Separates primitive values (tokens) from application (theme configuration).

### Theme Extensions

Uses Flutter's `ThemeExtension<T>` for strongly-typed custom design tokens.

### Functional Configuration

Standalone factory functions for theme generation with easy parameterization.

### Barrel Export

`design.dart` facade reduces import clutter.

### Platform Adaptation

`typography_x.dart` resolves platform-specific fonts (SF Mono vs Roboto Mono).

## Cross-Component Dependencies

### Depends On

- **17 - Utilities**: Platform resolver for font detection and platform-specific layout adjustments

### Used By

- **01 - App Shell**: Root theme configuration, home screen, and settings UI
- **02 - Authentication**: Login screen styling
- **05 - Threads**: History panel and thread list UI
- **06 - Rooms**: Room list and detail view styling
- **08 - Chat UI**: Chat interface styling
- **09 - Inspector**: HTTP inspector UI
- **10 - Configuration**: ThemeConfig model definitions
- **12 - Shared Widgets**: Base styling for reusable widgets
- **20 - Quiz**: Quiz screen styling

## Contribution Guidelines

### DO

- **Use Semantic Naming:** Define colors by intent (`primary`, `destructive`, `inputBackground`), not by appearance (`blue`, `red`).
- **Implement Lerp:** When adding new tokens to `ThemeExtension` classes, strictly implement the `lerp` method to support smooth theme switching animations.
- **Use the Facade:** Always import `package:soliplex_frontend/design/design.dart` instead of individual token files to simplify refactoring.
- **Parameterize Factories:** When modifying `soliplexLightTheme` or `soliplexDarkTheme`, ensure the logic relies on the injected `colors` argument, not hardcoded constants.
- **Platform Awareness:** Use `typography_x.dart` or similar extensions when font choices or spacing must differ between Web and Native platforms.

### DON'T

- **No Magic Numbers:** Never use raw doubles for padding or radius in widgets (e.g., `Padding(all: 8.0)`). Use `SoliplexSpacing.s2` or `soliplexRadii.md`.
- **No Hex Codes in UI:** Never use `Color(0xFF...)` or `Colors.red` in feature widgets. All colors must come from `Theme.of(context)` or `SoliplexTheme.of(context)`.
- **Avoid Logic in Tokens:** Token files should only contain `const` data or simple data classes. Logic belongs in `ThemeData` factories or extensions.
- **No Material Dependency in Tokens:** Avoid making Token definitions dependent on `BuildContext`. They should be plain Dart objects injectable into the Theme factory.
- **Don't Break Contrast:** When adding new color tokens, ensure high contrast ratios are maintained in both Light and Dark palettes.

### Extending This Component

- **Adding a Color:** Add the field to `SoliplexColors`, update `lightSoliplexColors` and `darkSoliplexColors`, and mapping logic in theme factories.
- **New Token Type:** Create a class (e.g., `SoliplexShadows`), add it to `SoliplexTheme` extension, implement `lerp`, and expose via `design.dart`.
- **Custom Component Style:** If a component needs specific styling, create a `ThemeExtension` for it rather than overloading the global color scheme.
