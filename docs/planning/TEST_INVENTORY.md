# Test Inventory

## Summary

| Location | Test Files | Coverage |
|----------|------------|----------|
| `test/` | 60 | App layer |
| `packages/soliplex_client/test/` | 39 | Client package |
| `packages/soliplex_client_native/test/` | 3 | Native package |
| **Total** | **102** | |

## Tests by Component

### 01 - App Shell & Entry

| Test File | Source Coverage |
|-----------|-----------------|
| `test/features/home/home_screen_test.dart` | HomeScreen |
| `test/features/home/connection_flow_test.dart` | Connection flow |
| `test/shared/widgets/app_shell_test.dart` | AppShell |

### 02 - Authentication Flow

| Test File | Source Coverage |
|-----------|-----------------|
| `test/core/auth/auth_flow_test.dart` | AuthFlow |
| `test/core/auth/auth_notifier_test.dart` | AuthNotifier |
| `test/core/auth/auth_provider_test.dart` | Auth providers |
| `test/core/auth/auth_state_test.dart` | AuthState sealed |
| `test/core/auth/auth_storage_test.dart` | AuthStorage |
| `test/core/auth/callback_params_test.dart` | CallbackParams |
| `test/core/auth/oidc_issuer_test.dart` | OidcIssuer |
| `test/features/auth/auth_callback_screen_test.dart` | AuthCallbackScreen |
| `test/features/login/login_screen_test.dart` | LoginScreen |
| `packages/soliplex_client/test/auth/oidc_discovery_test.dart` | OidcDiscovery |
| `packages/soliplex_client/test/auth/token_refresh_service_test.dart` | TokenRefreshService |

### 03 - State Management Core

| Test File | Source Coverage |
|-----------|-----------------|
| `test/core/providers/api_provider_test.dart` | apiProvider |
| `test/core/providers/config_provider_test.dart` | configProvider |
| `test/core/providers/shell_config_provider_test.dart` | shellConfigProvider |

### 04 - Active Run & Streaming

| Test File | Source Coverage |
|-----------|-----------------|
| `test/core/providers/active_run_provider_test.dart` | activeRunProvider |
| `test/core/providers/active_run_notifier_test.dart` | ActiveRunNotifier |
| `test/core/application/run_lifecycle_impl_test.dart` | RunLifecycleImpl |
| `packages/soliplex_client/test/application/agui_event_processor_test.dart` | AguiEventProcessor |
| `packages/soliplex_client/test/application/streaming_state_test.dart` | StreamingState |

### 05 - Thread Management

| Test File | Source Coverage |
|-----------|-----------------|
| `test/core/providers/threads_provider_test.dart` | threadsProvider |
| `test/core/providers/last_viewed_thread_test.dart` | lastViewedThreadProvider |
| `test/core/providers/thread_history_cache_test.dart` | threadHistoryCacheProvider |
| `test/features/history/history_panel_test.dart` | HistoryPanel |
| `packages/soliplex_client/test/domain/thread_history_test.dart` | ThreadHistory |

### 06 - Room Management

| Test File | Source Coverage |
|-----------|-----------------|
| `test/core/providers/rooms_provider_test.dart` | roomsProvider |
| `test/features/room/room_screen_test.dart` | RoomScreen |
| `test/features/rooms/rooms_screen_test.dart` | RoomsScreen |
| `packages/soliplex_client/test/domain/room_test.dart` | Room model |

### 07 - Document Selection

| Test File | Source Coverage |
|-----------|-----------------|
| `test/core/providers/selected_documents_provider_test.dart` | selectedDocumentsProvider |
| `packages/soliplex_client/test/domain/rag_document_test.dart` | RagDocument |

### 08 - Chat UI

| Test File | Source Coverage |
|-----------|-----------------|
| `test/features/chat/chat_panel_test.dart` | ChatPanel |
| `test/features/chat/widgets/chat_input_test.dart` | ChatInput |
| `test/features/chat/widgets/chat_message_widget_test.dart` | ChatMessageWidget |
| `test/features/chat/widgets/message_list_test.dart` | MessageList |
| `test/features/chat/widgets/citations_section_test.dart` | CitationsSection |
| `test/features/chat/widgets/chunk_visualization_page_test.dart` | ChunkVisualizationPage |
| `test/core/providers/citations_expanded_provider_test.dart` | citationsExpandedProvider |
| `test/core/providers/chunk_visualization_provider_test.dart` | chunkVisualizationProvider |
| `test/core/providers/source_references_provider_test.dart` | sourceReferencesProvider |

### 09 - HTTP Inspector

| Test File | Source Coverage |
|-----------|-----------------|
| `test/features/inspector/http_inspector_panel_test.dart` | HttpInspectorPanel |
| `test/features/inspector/models/http_event_group_test.dart` | HttpEventGroup |
| `test/features/inspector/models/http_event_grouper_test.dart` | HttpEventGrouper |
| `test/features/inspector/widgets/http_event_tile_test.dart` | HttpEventTile |
| `test/features/inspector/widgets/http_status_display_test.dart` | HttpStatusDisplay |
| `test/core/providers/http_log_provider_test.dart` | httpLogProvider |

### 10 - Configuration

| Test File | Source Coverage |
|-----------|-----------------|
| `test/core/models/app_config_test.dart` | AppConfig |
| `test/core/models/active_run_state_test.dart` | ActiveRunState |
| `test/core/models/features_test.dart` | Features |
| `test/core/models/logo_config_test.dart` | LogoConfig |
| `test/core/models/route_config_test.dart` | RouteConfig |
| `test/core/models/soliplex_config_test.dart` | SoliplexConfig |
| `test/core/models/theme_config_test.dart` | ThemeConfig |
| `test/features/settings/settings_screen_test.dart` | SettingsScreen |
| `test/features/settings/backend_versions_screen_test.dart` | BackendVersionsScreen |

### 11 - Design System

| Test File | Source Coverage |
|-----------|-----------------|
| `test/design/theme/theme_test.dart` | Theme system |

### 12 - Shared Widgets

| Test File | Source Coverage |
|-----------|-----------------|
| `test/shared/widgets/async_value_handler_test.dart` | AsyncValueHandler |
| `test/shared/widgets/error_display_test.dart` | ErrorDisplay |
| `test/shared/utils/date_formatter_test.dart` | DateFormatter |
| `test/shared/utils/format_utils_test.dart` | FormatUtils |

### 13 - Client: Domain Models

| Test File | Source Coverage |
|-----------|-----------------|
| `packages/soliplex_client/test/domain/auth_provider_config_test.dart` | AuthProviderConfig |
| `packages/soliplex_client/test/domain/backend_version_info_test.dart` | BackendVersionInfo |
| `packages/soliplex_client/test/domain/chat_message_test.dart` | ChatMessage |
| `packages/soliplex_client/test/domain/chunk_visualization_test.dart` | ChunkVisualization |
| `packages/soliplex_client/test/domain/citation_test.dart` | Citation |
| `packages/soliplex_client/test/domain/citation_formatting_test.dart` | Citation formatting |
| `packages/soliplex_client/test/domain/conversation_test.dart` | Conversation |
| `packages/soliplex_client/test/domain/message_state_test.dart` | MessageState |
| `packages/soliplex_client/test/domain/quiz_test.dart` | Quiz |
| `packages/soliplex_client/test/domain/run_info_test.dart` | RunInfo |
| `packages/soliplex_client/test/domain/source_reference_test.dart` | SourceReference |
| `packages/soliplex_client/test/domain/thread_info_test.dart` | ThreadInfo |

### 14 - Client: HTTP Layer

| Test File | Source Coverage |
|-----------|-----------------|
| `packages/soliplex_client/test/http/authenticated_http_client_test.dart` | AuthenticatedHttpClient |
| `packages/soliplex_client/test/http/dart_http_client_test.dart` | DartHttpClient |
| `packages/soliplex_client/test/http/http_client_adapter_test.dart` | HttpClientAdapter |
| `packages/soliplex_client/test/http/http_observer_test.dart` | HttpObserver |
| `packages/soliplex_client/test/http/http_redactor_test.dart` | HttpRedactor |
| `packages/soliplex_client/test/http/http_response_test.dart` | HttpResponse |
| `packages/soliplex_client/test/http/http_transport_test.dart` | HttpTransport |
| `packages/soliplex_client/test/http/observable_http_client_test.dart` | ObservableHttpClient |
| `packages/soliplex_client/test/http/refreshing_http_client_test.dart` | RefreshingHttpClient |

### 15 - Client: API Endpoints

| Test File | Source Coverage |
|-----------|-----------------|
| `packages/soliplex_client/test/api/fetch_auth_providers_test.dart` | fetchAuthProviders |
| `packages/soliplex_client/test/api/agui_message_mapper_test.dart` | AguiMessageMapper |
| `packages/soliplex_client/test/api/mappers_test.dart` | API mappers |
| `packages/soliplex_client/test/api/soliplex_api_test.dart` | SoliplexApi |

### 16 - Client: Application

| Test File | Source Coverage |
|-----------|-----------------|
| `packages/soliplex_client/test/application/citation_extractor_test.dart` | CitationExtractor |
| `packages/soliplex_client/test/application/json_patch_test.dart` | JsonPatch |

### 17 - Client: Utilities

| Test File | Source Coverage |
|-----------|-----------------|
| `packages/soliplex_client/test/utils/url_builder_test.dart` | UrlBuilder |
| `packages/soliplex_client/test/errors/exceptions_test.dart` | Exception types |

### 18 - Native Platform

| Test File | Source Coverage |
|-----------|-----------------|
| `packages/soliplex_client_native/test/platform/create_platform_client_test.dart` | createPlatformClient |
| `packages/soliplex_client_native/test/clients/cupertino_http_client_test.dart` | CupertinoHttpClient |

### 19 - Navigation & Routing

| Test File | Source Coverage |
|-----------|-----------------|
| `test/core/router/app_router_test.dart` | appRouter |

### 20 - Quiz Feature

| Test File | Source Coverage |
|-----------|-----------------|
| `test/core/providers/quiz_provider_test.dart` | quizProvider |
| `test/features/quiz/quiz_screen_test.dart` | QuizScreen |

## Contract Tests

| Test File | Purpose |
|-----------|---------|
| `test/api_contract/soliplex_frontend_contract_test.dart` | Frontend API contracts |
| `packages/soliplex_client/test/api_contract/soliplex_client_contract_test.dart` | Client package contracts |
| `packages/soliplex_client/test/schema/ask_history_contract_test.dart` | AskHistory schema |
| `packages/soliplex_client/test/schema/haiku_rag_chat_contract_test.dart` | HaikuRagChat schema |
| `packages/soliplex_client_native/test/api_contract/soliplex_client_native_contract_test.dart` | Native package contracts |

## Test Helpers

| Test File | Purpose |
|-----------|---------|
| `test/helpers/test_helpers.dart` | Shared mocks, fixtures, pumpWithProviders |
