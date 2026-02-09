import 'package:flutter/material.dart';

extension SymbolicColors on ColorScheme {
  bool get isDarkMode => brightness == Brightness.dark;

  Color get info =>
      brightness == Brightness.light ? Colors.blue : Colors.blue.shade300;

  /// Warning color that adapts to the current theme brightness.
  Color get warning =>
      brightness == Brightness.light ? Colors.orange : Colors.orange.shade300;

  /// Danger color that adapts to the current theme brightness.
  Color get danger =>
      brightness == Brightness.light ? Colors.red : Colors.red.shade300;

  /// Success color that adapts to the current theme brightness.
  Color get success =>
      brightness == Brightness.light ? Colors.green : Colors.green.shade300;
}
