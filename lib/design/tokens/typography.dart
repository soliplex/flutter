import 'package:flutter/material.dart';

import 'package:soliplex_frontend/design/tokens/colors.dart';

TextTheme soliplexTextTheme(SoliplexColors colors) {
  return TextTheme(
    bodyMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: colors.foreground,
    ),
    labelMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: colors.foreground,
    ),
    titleSmall: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: colors.foreground,
    ),
    titleMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: colors.foreground,
    ),
    titleLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: colors.foreground,
    ),
  );
}
