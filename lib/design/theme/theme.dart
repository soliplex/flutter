import 'package:flutter/material.dart';
import 'package:soliplex_frontend/design/theme/theme_extensions.dart';

import 'package:soliplex_frontend/design/tokens/colors.dart';
import 'package:soliplex_frontend/design/tokens/radii.dart';
import 'package:soliplex_frontend/design/tokens/spacing.dart';
import 'package:soliplex_frontend/design/tokens/typography.dart';
import 'package:soliplex_frontend/shared/widgets/markdown/markdown_theme_extension.dart';

/// Creates a light theme using the provided colors.
///
/// If [colors] is not provided, uses [lightSoliplexColors] as the default.
/// This allows white-label apps to customize the color palette while
/// preserving the theme structure.
ThemeData soliplexLightTheme({SoliplexColors colors = lightSoliplexColors}) {
  final textTheme = soliplexTextTheme(colors);
  final colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: colors.primary,
    onPrimary: colors.onPrimary,
    secondary: colors.secondary,
    onSecondary: colors.onSecondary,
    surface: colors.background,
    onSurface: colors.foreground,
    error: colors.destructive,
    onError: colors.onDestructive,
  );

  return ThemeData(
    brightness: Brightness.light,
    colorScheme: colorScheme,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.onPrimary,
      foregroundColor: colors.primary,
      elevation: 0,
      actionsPadding: const EdgeInsets.symmetric(
        horizontal: SoliplexSpacing.s2,
      ),
      shape: Border(bottom: BorderSide(color: colors.border)),
    ),
    dividerTheme: DividerThemeData(
      color: colors.border,
      thickness: 1,
      space: 1,
    ),
    buttonTheme: ButtonThemeData(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.circular(soliplexRadii.md),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.border),
          borderRadius: BorderRadius.circular(soliplexRadii.md),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.border),
          borderRadius: BorderRadius.circular(soliplexRadii.md),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.border),
          borderRadius: BorderRadius.circular(soliplexRadii.md),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.inputBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
        borderSide: BorderSide(color: colors.border, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
        borderSide: BorderSide(color: colors.destructive),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
        borderSide: BorderSide(color: colors.destructive, width: 2),
      ),
      hintStyle: TextStyle(color: colors.hintText),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
      ),
      selectedColor: colors.primary,
      selectedTileColor: colors.inputBackground,
    ),
    cardTheme: CardThemeData(
      color: colors.inputBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
      ),
      elevation: 0,
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.circular(soliplexRadii.md),
      ),
      collapsedShape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.circular(soliplexRadii.md),
      ),
      collapsedBackgroundColor: colors.inputBackground,
      backgroundColor: colors.onPrimary,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.inputBackground,
      selectedColor: colors.primary.withAlpha(25),
      disabledColor: colors.muted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
        side: BorderSide(color: colors.border),
      ),
      labelStyle: TextStyle(color: colors.foreground),
      secondaryLabelStyle: TextStyle(color: colors.foreground),
      padding: const EdgeInsets.symmetric(
        horizontal: SoliplexSpacing.s2,
        vertical: SoliplexSpacing.s1,
      ),
      secondarySelectedColor: colors.primary.withAlpha(25),
      brightness: Brightness.light,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.sm),
      ),
    ),
    toggleButtonsTheme: ToggleButtonsThemeData(
      borderRadius: BorderRadius.circular(soliplexRadii.md),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: textTheme.bodyMedium,
      menuStyle: MenuStyle(
        visualDensity: VisualDensity.compact,
        shape: WidgetStateProperty.all<OutlinedBorder?>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(soliplexRadii.md),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationThemeData(
        isDense: true,
        border: OutlineInputBorder(),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
      ),
      textStyle: textTheme.bodyMedium,
    ),
    scaffoldBackgroundColor: colors.background,
    useMaterial3: true,
    textTheme: textTheme,
    extensions: [
      SoliplexTheme(
        colors: colors,
        radii: soliplexRadii,
        badgeTheme: SoliplexBadgeThemeData(
          background: Color.alphaBlend(
            colors.foreground.withAlpha(15),
            colors.background,
          ),
          textStyle: textTheme.labelMedium!.copyWith(color: colors.foreground),
          padding: const EdgeInsets.symmetric(
            horizontal: SoliplexSpacing.s2,
            vertical: SoliplexSpacing.s1,
          ),
        ),
      ),
      _markdownThemeExtension(colorScheme, textTheme),
    ],
  );
}

/// Creates a dark theme using the provided colors.
///
/// If [colors] is not provided, uses [darkSoliplexColors] as the default.
/// This allows white-label apps to customize the color palette while
/// preserving the theme structure.
ThemeData soliplexDarkTheme({SoliplexColors colors = darkSoliplexColors}) {
  final textTheme = soliplexTextTheme(colors);
  final colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: colors.primary,
    onPrimary: colors.onPrimary,
    secondary: colors.secondary,
    onSecondary: colors.onSecondary,
    surface: colors.background,
    onSurface: colors.foreground,
    error: colors.destructive,
    onError: colors.onDestructive,
  );

  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.onPrimary,
      foregroundColor: colors.primary,
      elevation: 0,
      actionsPadding: const EdgeInsets.symmetric(
        horizontal: SoliplexSpacing.s2,
      ),
      shape: Border(bottom: BorderSide(color: colors.border)),
    ),
    dividerTheme: DividerThemeData(
      color: colors.border,
      thickness: 1,
      space: 1,
    ),
    buttonTheme: ButtonThemeData(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.circular(soliplexRadii.md),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.border),
          borderRadius: BorderRadius.circular(soliplexRadii.md),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.border),
          borderRadius: BorderRadius.circular(soliplexRadii.md),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.border),
          borderRadius: BorderRadius.circular(soliplexRadii.md),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.inputBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
        borderSide: BorderSide(color: colors.border, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
        borderSide: BorderSide(color: colors.destructive),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
        borderSide: BorderSide(color: colors.destructive, width: 2),
      ),
      hintStyle: TextStyle(color: colors.hintText),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
      ),
      selectedColor: colors.primary,
      selectedTileColor: colors.inputBackground,
    ),
    cardTheme: CardThemeData(
      color: colors.inputBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
      ),
      elevation: 0,
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.circular(soliplexRadii.md),
      ),
      collapsedShape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.circular(soliplexRadii.md),
      ),
      collapsedBackgroundColor: colors.inputBackground,
      backgroundColor: colors.onPrimary,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.inputBackground,
      selectedColor: colors.primary.withAlpha(25),
      disabledColor: colors.muted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
        side: BorderSide(color: colors.border),
      ),
      labelStyle: TextStyle(color: colors.foreground),
      secondaryLabelStyle: TextStyle(color: colors.foreground),
      padding: const EdgeInsets.symmetric(
        horizontal: SoliplexSpacing.s2,
        vertical: SoliplexSpacing.s1,
      ),
      secondarySelectedColor: colors.primary.withAlpha(25),
      brightness: Brightness.dark,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.sm),
      ),
    ),
    toggleButtonsTheme: ToggleButtonsThemeData(
      borderRadius: BorderRadius.circular(soliplexRadii.md),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: textTheme.bodyMedium,
      menuStyle: MenuStyle(
        visualDensity: VisualDensity.compact,
        shape: WidgetStateProperty.all<OutlinedBorder?>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(soliplexRadii.md),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationThemeData(
        isDense: true,
        border: OutlineInputBorder(),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(soliplexRadii.md),
      ),
      textStyle: textTheme.bodyMedium,
    ),
    scaffoldBackgroundColor: colors.background,
    useMaterial3: true,
    textTheme: textTheme,
    extensions: [
      SoliplexTheme(
        colors: colors,
        radii: soliplexRadii,
        badgeTheme: SoliplexBadgeThemeData(
          background: Color.alphaBlend(
            colors.foreground.withAlpha(15),
            colors.background,
          ),
          textStyle: textTheme.labelMedium!.copyWith(color: colors.foreground),
          padding: const EdgeInsets.symmetric(
            horizontal: SoliplexSpacing.s2,
            vertical: SoliplexSpacing.s1,
          ),
        ),
      ),
      _markdownThemeExtension(colorScheme, textTheme),
    ],
  );
}

MarkdownThemeExtension _markdownThemeExtension(
  ColorScheme colorScheme,
  TextTheme textTheme,
) {
  return MarkdownThemeExtension(
    h1: textTheme.titleLarge,
    h2: textTheme.titleMedium,
    h3: textTheme.titleSmall,
    body: textTheme.bodyMedium,
    code: textTheme.bodyMedium?.copyWith(
      backgroundColor: colorScheme.surfaceContainerHigh,
    ),
    link: TextStyle(
      color: colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: colorScheme.primary,
    ),
    codeBlockDecoration: BoxDecoration(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(soliplexRadii.sm),
    ),
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(
          color: colorScheme.outlineVariant,
          width: 3,
        ),
      ),
    ),
  );
}
