import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:soliplex_frontend/shared/utils/platform_resolver.dart';

class AdaptiveDialogAction<T> {
  const AdaptiveDialogAction({
    required this.child,
    this.value,
    this.onPressed,
    this.isDefault = false,
    this.isDestructive = false,
  });

  final Widget child;
  final T? value;
  final bool isDefault;
  final bool isDestructive;
  final VoidCallback? onPressed;
}

Future<T?> showPlatformAdaptiveDialog<T>({
  required BuildContext context,
  required List<AdaptiveDialogAction<T>> actions,
  Widget? title,
  Widget? content,
  bool barrierDismissible = false,
}) {
  if (isCupertino(context)) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => CupertinoAlertDialog(
        title: title,
        content: content,
        actions: actions.map((a) {
          return CupertinoDialogAction(
            isDefaultAction: a.isDefault,
            isDestructiveAction: a.isDestructive,
            onPressed: a.onPressed ?? () => Navigator.pop(context, a.value),
            child: a.child,
          );
        }).toList(),
      ),
    );
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => AlertDialog(
      title: title,
      content: content,
      actions: actions.map((a) {
        return TextButton(
          onPressed: () => Navigator.pop(context, a.value),
          child: a.child,
        );
      }).toList(),
    ),
  );
}
