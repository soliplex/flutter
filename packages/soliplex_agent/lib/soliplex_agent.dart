/// Pure Dart agent orchestration for Soliplex AI runtime.
///
/// This package provides the core types and orchestration logic for
/// running AI agents. It depends only on `soliplex_client` and
/// `soliplex_logging` — no Flutter imports allowed.
library;

// Re-exported from soliplex_client (moved in agent-package-split refactor).
export 'package:soliplex_client/run.dart';

export 'src/host/fake_host_api.dart';
export 'src/host/host_api.dart';
export 'src/host/native_platform_constraints.dart';
export 'src/host/platform_constraints.dart';
export 'src/host/web_platform_constraints.dart';
export 'src/models/agent_result.dart';
export 'src/runtime/agent_runtime.dart';
export 'src/runtime/agent_session.dart';
export 'src/runtime/agent_session_state.dart';
export 'src/tools/tool_registry_resolver.dart';
