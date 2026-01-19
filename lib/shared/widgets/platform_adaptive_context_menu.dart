import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:soliplex_frontend/shared/utils/platform_resolver.dart';

class PlatformAdaptiveContextMenuAction {
  const PlatformAdaptiveContextMenuAction({
    required this.child,
    required this.onPressed,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onPressed;
  final bool enabled;
}

class PlatformAdaptiveContextMenu<T> extends StatelessWidget {
  PlatformAdaptiveContextMenu({
    required this.actions,
    super.key,
  });

  final GlobalKey buttonKey = GlobalKey();
  final List<PlatformAdaptiveContextMenuAction> actions;

  Rect _getWidgetGlobalRect(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    final position = renderBox?.localToGlobal(Offset.zero);
    if (renderBox != null && position != null) {
      return Rect.fromLTWH(
        position.dx,
        position.dy,
        renderBox.size.width,
        renderBox.size.height,
      );
    }
    return Rect.zero;
  }

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) return _buildCupertinoMenu(context);

    return _buildMaterialMenu(context);
  }

  Widget _buildMaterialMenu(BuildContext context) {
    return InkWell(
      key: buttonKey,
      onTap: () {
        showMenu(
          context: context,
          position: RelativeRect.fromRect(
            _getWidgetGlobalRect(buttonKey),
            Offset.zero & MediaQuery.of(context).size,
          ),
          items: actions
              .map(
                (action) => PopupMenuItem<T>(
                  enabled: action.enabled,
                  child: action.child,
                  onTap: () {
                    Navigator.of(context).pop();
                    action.onPressed();
                  },
                ),
              )
              .toList(),
        );
      },
      child: const Icon(Icons.more_vert),
    );
  }

  Widget _buildCupertinoMenu(BuildContext context) {
    return CupertinoContextMenu(
      actions: actions
          .map(
            (action) => CupertinoContextMenuAction(
              onPressed: action.onPressed,
              child: action.child,
            ),
          )
          .toList(),
      child: InkWell(
        key: buttonKey,
        child: const Icon(Icons.more_vert),
      ),
    );
  }
}
