import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/models/soliplex_config.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/inspector/http_inspector_panel.dart';
import 'package:soliplex_frontend/shared/widgets/shell_config.dart';
import 'package:soliplex_frontend/shared/widgets/theme_toggle_button.dart';

/// Shell widget that wraps all screens with a single Scaffold.
///
/// Provides:
/// - Single Scaffold to avoid nested Scaffold drawer issues
/// - HTTP inspector drawer accessible from all screens (if enabled)
/// - Consistent AppBar with configurable actions and theme toggle
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
    final shellConfig = ref.watch(shellConfigProvider);
    final features = ref.watch(featuresProvider);
    final showInspector =
        features.enableHttpInspector && customEndDrawer == null;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            // Left group — intrinsic width
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: SoliplexSpacing.s2,
              children: [
                if (config.leading != null) config.leading!,
                if (shellConfig.showLogoInAppBar)
                  _BrandLogo(config: shellConfig),
                if (shellConfig.showLogoInAppBar &&
                    shellConfig.showAppNameInAppBar)
                  Text(
                    shellConfig.appName,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
              ],
            ),
            // Page title — centered in remaining space
            Expanded(
              child: config.title != null
                  ? Center(child: config.title)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: SoliplexSpacing.s2),
            child: ThemeToggleButton(),
          ),
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

/// Brand logo for the AppBar.
///
/// Renders the configured logo asset with an error fallback icon.
class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.config});

  final SoliplexConfig config;

  @override
  Widget build(BuildContext context) {
    const double logoHeight = 40;

    return Image.asset(
      config.logo.assetPath,
      package: config.logo.package,
      height: logoHeight,
      fit: BoxFit.contain,
      semanticLabel: '${config.appName} logo',
      errorBuilder: (context, error, stack) => const Icon(
        Icons.image_not_supported_outlined,
        size: logoHeight,
      ),
    );
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
