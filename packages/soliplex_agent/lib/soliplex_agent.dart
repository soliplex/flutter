/// Pure Dart agent orchestration for Soliplex AI runtime.
///
/// This package provides the core types and orchestration logic for
/// running AI agents. It depends only on `soliplex_client` and
/// `soliplex_logging` — no Flutter imports allowed.
library;

// Re-export client types so consumers only depend on soliplex_agent.
// Hide HTTP/auth/util internals — consumers use createClientBundle() instead.
export 'package:soliplex_client/soliplex_client.dart'
    hide
        AuthenticatedHttpClient,
        DartHttpClient,
        HttpClientAdapter,
        HttpObserver,
        HttpResponse,
        HttpTransport,
        ObservableHttpClient,
        OidcDiscoveryDocument,
        RefreshingHttpClient,
        SoliplexHttpClient,
        TokenRefreshFailure,
        TokenRefreshResult,
        TokenRefreshService,
        TokenRefreshSuccess,
        TokenRefresher,
        UrlBuilder;

// ── Client Wiring ──
export 'src/client_bundle.dart';

// ── Host API ──
export 'src/host/agent_api.dart';
export 'src/host/fake_agent_api.dart';
export 'src/host/fake_host_api.dart';
export 'src/host/form_api.dart';
export 'src/host/host_api.dart';
export 'src/host/native_platform_constraints.dart';
export 'src/host/platform_constraints.dart';
export 'src/host/runtime_agent_api.dart';
export 'src/host/web_platform_constraints.dart';

// ── Models ──
export 'src/models/agent_result.dart';
export 'src/models/failure_reason.dart';
export 'src/models/thread_key.dart';

// ── Orchestration ──
export 'src/orchestration/error_classifier.dart';
export 'src/orchestration/run_orchestrator.dart';
export 'src/orchestration/run_state.dart';

// ── Runtime ──
export 'src/runtime/agent_runtime.dart';
export 'src/runtime/agent_session.dart';
export 'src/runtime/agent_session_state.dart';
export 'src/runtime/multi_server_runtime.dart';
export 'src/runtime/server_connection.dart';
export 'src/runtime/server_registry.dart';

// ── Scripting ──
export 'src/scripting/script_environment.dart';

// ── Tools ──
export 'src/tools/tool_registry.dart';
export 'src/tools/tool_registry_resolver.dart';
