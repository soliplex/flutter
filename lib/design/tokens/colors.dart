import 'package:flutter/material.dart';

class SoliplexColors {
  const SoliplexColors({
    required this.background,
    required this.foreground,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.accent,
    required this.onAccent,
    required this.muted,
    required this.mutedForeground,
    required this.destructive,
    required this.onDestructive,
    required this.border,
    required this.inputBackground,
    required this.hintText,
  });

  final Color background;
  final Color foreground;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color accent;
  final Color onAccent;
  final Color muted;
  final Color mutedForeground;
  final Color destructive;
  final Color onDestructive;
  final Color border;
  final Color inputBackground;
  final Color hintText;
}

// NOTE: OKLCH values have been approximately converted to sRGB for Flutter

const lightSoliplexColors = SoliplexColors(
  background: Color(0xffffffff),
  foreground: Color(0xFF0A0A0A),
  primary: Color(0xFF030213),
  onPrimary: Color(0xffffffff),
  secondary: Color(0xFFF3F3FA),
  onSecondary: Color(0xFF030213),
  accent: Color(0xFFE9EBEF),
  onAccent: Color(0xFF030213),
  muted: Color(0xFFECECF0),
  mutedForeground: Color(0xFF717182),
  destructive: Color(0xFFD4183D),
  onDestructive: Color(0xffffffff),
  border: Color(0x1A000000),
  inputBackground: Color(0xFFF3F3F5),
  hintText: Color(0xFF999999),
);

const darkSoliplexColors = SoliplexColors(
  background: Color(0xFF111111),
  foreground: Color(0xFFFAFAFA),
  primary: Color(0xFFFAFAFA),
  onPrimary: Color(0xFF222222),
  secondary: Color(0xFF2A2A2A),
  onSecondary: Color(0xFFFFFFFF),
  accent: Color(0xFF2A2A2A),
  onAccent: Color(0xFFFFFFFF),
  muted: Color(0xFF444444),
  mutedForeground: Color(0xFFAAAAAA),
  destructive: Color(0xFFD4183D),
  onDestructive: Color(0xFFFFFFFF),
  border: Color(0xFF2A2A2A),
  inputBackground: Color(0xFF333333),
  hintText: Color(0xFF999999),
);
