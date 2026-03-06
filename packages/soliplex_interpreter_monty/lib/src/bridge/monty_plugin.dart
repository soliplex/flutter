import 'package:meta/meta.dart';
import 'package:soliplex_interpreter_monty/src/bridge/host_function.dart';
import 'package:soliplex_interpreter_monty/src/bridge/monty_bridge.dart';

/// Extension point for providing host functions to a [MontyBridge].
///
/// Each plugin declares a unique [namespace], a set of [functions], and
/// optional lifecycle hooks ([onRegister], [onDispose]).
abstract class MontyPlugin {
  /// Unique namespace prefix (e.g., "df", "chart", "sqlite").
  String get namespace;

  /// Human-readable description for LLM system prompt.
  ///
  /// Return `null` if the plugin has no additional prompt context beyond
  /// its function schemas.
  String? get systemPromptContext => null;

  /// Host functions this plugin provides.
  List<HostFunction> get functions;

  /// Called when attached to a bridge.
  @mustCallSuper
  Future<void> onRegister(MontyBridge bridge) async {}

  /// Called when session ends. Must be idempotent.
  @mustCallSuper
  Future<void> onDispose() async {}
}
