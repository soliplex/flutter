// Native is the default, web overrides when js_interop is available.
import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:soliplex_frontend/core/services/monty_platform_factory_native.dart'
    if (dart.library.js_interop) 'package:soliplex_frontend/core/services/monty_platform_factory_web.dart'
    as impl;

/// Creates a platform-appropriate [MontyPlatform] instance.
///
/// - **Native**: Returns a `MontyNative` with its own Isolate
///   (true parallel Python execution per thread).
/// - **Web**: Returns a `MontyWasm` with serialized access to the
///   shared `window.DartMontyBridge` singleton.
MontyPlatform createMontyPlatform() => impl.createMontyPlatform();
