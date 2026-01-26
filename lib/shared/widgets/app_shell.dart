import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/inspector/http_inspector_panel.dart';
import 'package:soliplex_frontend/shared/widgets/shell_config.dart';

/// Shell widget that wraps all screens with a single Scaffold.
///
/// Provides:
/// - Single Scaffold to avoid nested Scaffold drawer issues
/// - HTTP inspector drawer accessible from all screens (if enabled)
/// - Consistent AppBar with configurable actions
/// - Support for custom end drawers
///
/// The HTTP inspector can be disabled via `Features.enableHttpInspector`.
class AppShell extends ConsumerWidget {
  const AppShell({
    required this.config,
    required this.body,
    this.customEndDrawer,
    super.key,
  });

  /// Configuration for the AppBar and drawers.
  final ShellConfig config;

  /// The screen's body content.
  final Widget body;

  /// Optional custom end drawer to replace the HTTP inspector.
  ///
  /// If provided, this drawer is shown instead of the HTTP inspector.
  /// The HTTP inspector button is also hidden when a custom drawer is set.
  final Widget? customEndDrawer;

  double _getDrawerWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= SoliplexBreakpoints.desktop) {
      return 600;
    } else if (screenWidth >= SoliplexBreakpoints.tablet) {
      return 400;
    } else {
      return screenWidth * 0.8;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(featuresProvider);
    final showInspector =
        features.enableHttpInspector && customEndDrawer == null;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: SoliplexSpacing.s6,
          children: [
            if (config.leading != null) config.leading!,
            if (config.title != null) Flexible(child: config.title!),
          ],
        ),
        actions: [
          ...config.actions,
          if (showInspector)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: SoliplexSpacing.s2),
              child: _InspectorButton(),
            ),
        ],
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
      endDrawer: _buildEndDrawer(context, showInspector),
      body: SafeArea(child: body),
    );
  }

  Widget? _buildEndDrawer(BuildContext context, bool showInspector) {
    if (customEndDrawer != null) {
      return Semantics(
        label: 'Custom panel',
        child: SizedBox(
          width: _getDrawerWidth(context),
          child: Drawer(
            child: SafeArea(left: false, right: false, child: customEndDrawer!),
          ),
        ),
      );
    }

    if (showInspector) {
      return Semantics(
        label: 'HTTP traffic inspector panel',
        child: SizedBox(
          width: _getDrawerWidth(context),
          child: const Drawer(
            child: SafeArea(
              left: false,
              right: false,
              child: HttpInspectorPanel(),
            ),
          ),
        ),
      );
    }

    return null;
  }
}

/// Button that opens the HTTP inspector drawer.
///
/// Separate widget class ensures build() provides the correct context
/// for Scaffold.of() to find the Scaffold we just built.
class _InspectorButton extends StatelessWidget {
  const _InspectorButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'HTTP traffic inspector',
      child: IconButton(
        icon: const Icon(Icons.bug_report),
        tooltip: 'Open HTTP traffic inspector',
        onPressed: () => Scaffold.of(context).openEndDrawer(),
      ),
    );
  }
}
