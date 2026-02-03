import 'package:flutter/material.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/shared/widgets/shell_config.dart';

/// Shell widget that wraps all screens with a single Scaffold.
///
/// Provides:
/// - Single Scaffold to avoid nested Scaffold drawer issues
/// - Consistent AppBar with configurable leading widgets and actions
/// - Support for navigation drawers
///
/// The HTTP inspector is accessible via Settings > Network Requests.
class AppShell extends StatelessWidget {
  const AppShell({
    required this.config,
    required this.body,
    super.key,
  });

  /// Configuration for the AppBar and drawers.
  final ShellConfig config;

  /// The screen's body content.
  final Widget body;

  /// Standard width for a single leading widget (IconButton).
  static const double _singleLeadingWidth = 56;

  /// Calculate the leading width based on number of leading widgets.
  double _calculateLeadingWidth() {
    if (config.leading.isEmpty) return 0;
    if (config.leading.length == 1) return _singleLeadingWidth;
    // Multiple widgets: give enough space for a Row
    return config.leading.length * _singleLeadingWidth;
  }

  /// Build the leading widget for AppBar.
  Widget? _buildLeading() {
    if (config.leading.isEmpty) return null;
    if (config.leading.length == 1) return config.leading.first;
    return Padding(
      padding: const EdgeInsets.all(SoliplexSpacing.s2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: config.leading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _buildLeading(),
        leadingWidth: _calculateLeadingWidth(),
        title: config.title,
        actions: config.actions.isNotEmpty
            ? [
                ...config.actions,
                const SizedBox(width: SoliplexSpacing.s2),
              ]
            : null,
      ),
      drawer: config.drawer != null
          ? Semantics(
              label: 'Navigation drawer',
              child: Drawer(
                child: SafeArea(
                  left: false,
                  right: false,
                  child: config.drawer!,
                ),
              ),
            )
          : null,
      body: SafeArea(child: body),
    );
  }
}

/// Button that opens the navigation drawer.
///
/// Separate widget class ensures build() provides the correct context
/// for Scaffold.of() to find the Scaffold we just built.
class DrawerToggle extends StatelessWidget {
  const DrawerToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: 'Open navigation',
      onPressed: () => Scaffold.of(context).openDrawer(),
    );
  }
}
