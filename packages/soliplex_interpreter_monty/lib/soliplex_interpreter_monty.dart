/// Bridge Monty sandboxed Python interpreter into Soliplex (pure Dart).
library;

// Re-export bridge infrastructure from dart_monty_bridge.
export 'package:dart_monty_bridge/dart_monty_bridge.dart'
    show
        BridgeEvent,
        BridgeEventLoopResumed,
        BridgeEventLoopWaiting,
        BridgeRunError,
        BridgeRunFinished,
        BridgeRunStarted,
        BridgeStepFinished,
        BridgeStepStarted,
        BridgeTextContent,
        BridgeTextEnd,
        BridgeTextStart,
        BridgeToolCallArgs,
        BridgeToolCallEnd,
        BridgeToolCallResult,
        BridgeToolCallStart,
        BridgeUiRendered,
        DefaultMontyBridge,
        EventLoopBridge,
        HostFunction,
        HostFunctionHandler,
        HostFunctionRegistry,
        HostFunctionSchema,
        HostParam,
        HostParamType,
        IsolatePlugin,
        MontyBridge,
        MontyPlugin;

// Soliplex-only types.
export 'src/bridge/tool_definition_converter.dart';
export 'src/console_event.dart';
export 'src/execution_result.dart';
export 'src/input_variable.dart';
export 'src/monty_execution_service.dart';
export 'src/monty_limits_defaults.dart';
export 'src/schema_executor.dart';
