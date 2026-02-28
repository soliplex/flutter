import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the thread history sidebar is collapsed on desktop.
///
/// Lifted from local state in RoomScreen so that LLM tools
/// (e.g., `toggle_sidebar`) can control sidebar visibility.
class SidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  // ignore: use_setters_to_change_properties
  void set({required bool collapsed}) => state = collapsed;
}

final sidebarCollapsedProvider =
    NotifierProvider<SidebarCollapsedNotifier, bool>(
  SidebarCollapsedNotifier.new,
);
