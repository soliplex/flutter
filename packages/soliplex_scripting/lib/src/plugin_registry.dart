import 'dart:collection';

import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

/// Mixin for plugins whose function names predate the `namespace_` prefix
/// convention.
///
/// When applied, the [PluginRegistry] skips the prefix check for names listed
/// in [legacyNames]. New functions added to the same plugin MUST still follow
/// the `namespace_` prefix convention.
mixin LegacyUnprefixedPlugin on MontyPlugin {
  /// Function names that are grandfathered and do not require the namespace
  /// prefix.
  Set<String> get legacyNames;
}

/// Collects [MontyPlugin]s with namespace validation and function name
/// collision detection, then wires them onto a [MontyBridge].
///
/// All function names must be prefixed with the plugin's namespace followed
/// by an underscore (e.g., namespace `sqlite` requires functions named
/// `sqlite_query`, `sqlite_execute`, etc.) unless the plugin uses
/// [LegacyUnprefixedPlugin].
class PluginRegistry {
  final List<MontyPlugin> _plugins = [];
  final Set<String> _namespaces = {};
  final Set<String> _functionNames = {};

  static final RegExp _validNamespace = RegExp(r'^[a-z][a-z0-9_]*$');
  static const int _maxNamespaceLength = 32;
  static const Set<String> _reservedNamespaces = {'introspection'};

  /// Registered plugins in insertion order (unmodifiable).
  List<MontyPlugin> get plugins => UnmodifiableListView(_plugins);

  /// Validates [plugin] namespace and function names, then registers it.
  ///
  /// Throws [ArgumentError] if the namespace is empty, malformed, or exceeds
  /// 32 characters.
  /// Throws [StateError] if the namespace is reserved, already registered, or
  /// any function name collides with a previously registered function.
  void register(MontyPlugin plugin) {
    _validateNamespace(plugin.namespace);
    _checkFunctionCollisions(plugin);

    _namespaces.add(plugin.namespace);
    for (final fn in plugin.functions) {
      _functionNames.add(fn.schema.name);
    }
    _plugins.add(plugin);
  }

  /// Registers all plugin functions (plus introspection builtins) onto
  /// [bridge], then calls [MontyPlugin.onRegister] on each plugin.
  ///
  /// When [extraFunctions] is provided, they are registered under the
  /// `extra` category and included in introspection output.
  Future<void> attachTo(
    MontyBridge bridge, {
    List<HostFunction>? extraFunctions,
  }) async {
    final hostRegistry = HostFunctionRegistry();
    for (final plugin in _plugins) {
      hostRegistry.addCategory(plugin.namespace, plugin.functions);
    }
    if (extraFunctions != null && extraFunctions.isNotEmpty) {
      hostRegistry.addCategory('extra', extraFunctions);
    }
    hostRegistry.registerAllOnto(bridge);
    for (final plugin in _plugins) {
      await plugin.onRegister(bridge);
    }
  }

  /// Calls [MontyPlugin.onDispose] on each registered plugin.
  Future<void> disposeAll() async {
    for (final plugin in _plugins) {
      await plugin.onDispose();
    }
  }

  void _validateNamespace(String namespace) {
    if (namespace.isEmpty) {
      throw ArgumentError('Namespace must not be empty.');
    }
    if (namespace.length > _maxNamespaceLength) {
      throw ArgumentError(
        'Namespace "$namespace" exceeds maximum length of '
        '$_maxNamespaceLength characters.',
      );
    }
    if (!_validNamespace.hasMatch(namespace)) {
      throw ArgumentError(
        'Namespace "$namespace" contains invalid characters. '
        'Must match [a-z][a-z0-9_]*.',
      );
    }
    if (_reservedNamespaces.contains(namespace)) {
      throw StateError('Namespace "$namespace" is reserved.');
    }
    if (_namespaces.contains(namespace)) {
      throw StateError('Namespace "$namespace" already registered.');
    }
  }

  void _checkFunctionCollisions(MontyPlugin plugin) {
    final prefix = '${plugin.namespace}_';
    final legacyNames = plugin is LegacyUnprefixedPlugin
        ? plugin.legacyNames
        : const <String>{};
    final seen = <String>{};
    for (final fn in plugin.functions) {
      final name = fn.schema.name;
      if (!legacyNames.contains(name) && !name.startsWith(prefix)) {
        throw ArgumentError(
          'Function "$name" in plugin "${plugin.namespace}" must be '
          'prefixed with "$prefix".',
        );
      }
      if (_functionNames.contains(name) || !seen.add(name)) {
        throw StateError(
          'Function "$name" from plugin "${plugin.namespace}" conflicts '
          'with an already registered function.',
        );
      }
    }
  }
}
