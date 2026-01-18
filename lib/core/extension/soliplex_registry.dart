import 'package:flutter/widgets.dart';

/// Registry interface for extending Soliplex with custom functionality.
///
/// White-label apps implement this interface to register custom panels,
/// commands, and routes that integrate with the Soliplex shell.
///
/// Example usage:
/// ```dart
/// class MyAppRegistry implements SoliplexRegistry {
///   @override
///   List<PanelDefinition> get panels => [
///     PanelDefinition(
///       id: 'analytics',
///       label: 'Analytics',
///       icon: Icons.analytics,
///       builder: (context) => const AnalyticsPanel(),
///     ),
///   ];
///
///   @override
///   List<CommandDefinition> get commands => [];
///
///   @override
///   List<RouteDefinition> get routes => [];
/// }
/// ```
abstract interface class SoliplexRegistry {
  /// Custom panel definitions to add to the UI.
  ///
  /// Panels appear in designated areas like sidebars or drawers.
  List<PanelDefinition> get panels;

  /// Custom command definitions for slash commands.
  ///
  /// Commands can be invoked via the chat input with '/' prefix.
  List<CommandDefinition> get commands;

  /// Custom route definitions to add to the router.
  ///
  /// Routes are merged with the built-in Soliplex routes.
  List<RouteDefinition> get routes;
}

/// An empty registry with no custom functionality.
///
/// Used as the default when no custom registry is provided.
class EmptyRegistry implements SoliplexRegistry {
  /// Creates an empty registry.
  const EmptyRegistry();

  @override
  List<PanelDefinition> get panels => const [];

  @override
  List<CommandDefinition> get commands => const [];

  @override
  List<RouteDefinition> get routes => const [];
}

/// Definition of a custom panel for the shell UI.
class PanelDefinition {
  /// Creates a panel definition.
  const PanelDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
  });

  /// Unique identifier for the panel.
  final String id;

  /// Display label shown in UI.
  final String label;

  /// Icon for the panel.
  final IconData icon;

  /// Builder function to create the panel widget.
  final WidgetBuilder builder;
}

/// Definition of a custom slash command.
class CommandDefinition {
  /// Creates a command definition.
  const CommandDefinition({
    required this.name,
    required this.description,
    required this.handler,
  });

  /// Command name without the '/' prefix.
  final String name;

  /// Human-readable description shown in command help.
  final String description;

  /// Handler called when the command is invoked.
  ///
  /// Receives the command arguments (text after the command name).
  /// Returns a string response to display in chat, or null for no response.
  final Future<String?> Function(String arguments) handler;
}

/// Definition of a custom route.
class RouteDefinition {
  /// Creates a route definition.
  const RouteDefinition({
    required this.path,
    required this.builder,
    this.redirect,
  });

  /// Route path (e.g., '/custom-page').
  final String path;

  /// Builder function to create the page widget.
  ///
  /// Receives route state for accessing path parameters.
  final Widget Function(BuildContext context, Map<String, String> pathParams)
      builder;

  /// Optional redirect function.
  ///
  /// If provided, can return a path to redirect to, or null to proceed.
  final String? Function(BuildContext context)? redirect;
}
