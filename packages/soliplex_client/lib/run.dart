/// Run orchestration types for agent packages.
///
/// These types are intentionally excluded from the main
/// `package:soliplex_client/soliplex_client.dart` barrel to avoid name
/// collisions with the frontend app's own `ThreadKey` and run-state types.
///
/// Agent-layer packages should import this entry point:
/// ```dart
/// import 'package:soliplex_client/run.dart';
/// ```
library;

export 'src/application/error_classifier.dart';
export 'src/application/run_orchestrator.dart';
export 'src/application/run_state.dart';
export 'src/domain/failure_reason.dart';
export 'src/domain/thread_key.dart';
