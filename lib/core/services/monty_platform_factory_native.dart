import 'package:dart_monty_native/dart_monty_native.dart';
import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';

/// Creates a native [MontyPlatform] with its own Dart Isolate.
///
/// Each call returns a fresh instance — callers get independent Python
/// interpreters that can execute in parallel.
MontyPlatform createMontyPlatform() =>
    MontyNative(bindings: NativeIsolateBindingsImpl());
