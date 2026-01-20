import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Settings navigation button for AppBar.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Settings',
      child: IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () => context.push('/settings'),
        tooltip: 'Open settings',
      ),
    );
  }
}

/// Returns standard AppBar actions for the given path.
///
/// Settings button is included for all paths except those under `/settings`.
/// Screens can spread these into their actions list alongside custom actions.
List<Widget> standardActions(String path) {
  return [
    if (!path.startsWith('/settings')) const SettingsButton(),
  ];
}
