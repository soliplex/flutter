import 'package:flutter/material.dart';

/// Configuration for AppShell's Scaffold.
///
/// Screens provide this to configure the shell without having their own
/// Scaffold. This avoids nested Scaffold issues where inner Scaffolds
/// can't access the shell's drawers.
class ShellConfig {
  const ShellConfig({
    this.title,
    this.leading = const [],
    this.actions = const [],
    this.drawer,
  });

  /// The primary widget displayed in the AppBar.
  final Widget? title;

  /// Widgets to display in the AppBar's leading area, in order.
  ///
  /// Common patterns:
  /// - Mobile: `[backButton, DrawerToggle()]` - back navigation + hamburger menu
  /// - Desktop: `[sidebarToggle]` - inline sidebar collapse/expand
  ///
  /// The order in this list determines the visual order left-to-right.
  final List<Widget> leading;

  /// Widgets to display in the AppBar's actions area.
  final List<Widget> actions;

  /// Optional drawer for mobile navigation (e.g., thread list).
  final Widget? drawer;
}
