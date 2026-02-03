# File Inventory

Total production files: 156

---

## 01 - App Shell & Entry (8 files)

| File | Path |
|------|------|
| app.dart | lib/app.dart |
| main.dart | lib/main.dart |
| run_soliplex_app.dart | lib/run_soliplex_app.dart |
| soliplex_frontend.dart | lib/soliplex_frontend.dart |
| version.dart | lib/version.dart |
| connection_flow.dart | lib/features/home/connection_flow.dart |
| home_screen.dart | lib/features/home/home_screen.dart |
| settings_screen.dart | lib/features/settings/settings_screen.dart |

---

## 02 - Authentication Flow (19 files)

| File | Path |
|------|------|
| auth_flow.dart | lib/core/auth/auth_flow.dart |
| auth_flow_native.dart | lib/core/auth/auth_flow_native.dart |
| auth_flow_web.dart | lib/core/auth/auth_flow_web.dart |
| auth_notifier.dart | lib/core/auth/auth_notifier.dart |
| auth_provider.dart | lib/core/auth/auth_provider.dart |
| auth_state.dart | lib/core/auth/auth_state.dart |
| auth_storage.dart | lib/core/auth/auth_storage.dart |
| auth_storage_native.dart | lib/core/auth/auth_storage_native.dart |
| auth_storage_web.dart | lib/core/auth/auth_storage_web.dart |
| callback_params.dart | lib/core/auth/callback_params.dart |
| oidc_issuer.dart | lib/core/auth/oidc_issuer.dart |
| web_auth_callback.dart | lib/core/auth/web_auth_callback.dart |
| web_auth_callback_native.dart | lib/core/auth/web_auth_callback_native.dart |
| web_auth_callback_web.dart | lib/core/auth/web_auth_callback_web.dart |
| auth_callback_screen.dart | lib/features/auth/auth_callback_screen.dart |
| login_screen.dart | lib/features/login/login_screen.dart |
| auth.dart | packages/soliplex_client/lib/src/auth/auth.dart |
| oidc_discovery.dart | packages/soliplex_client/lib/src/auth/oidc_discovery.dart |
| token_refresh_service.dart | packages/soliplex_client/lib/src/auth/token_refresh_service.dart |

---

## 03 - State Management Core (5 files)

| File | Path |
|------|------|
| api_provider.dart | lib/core/providers/api_provider.dart |
| backend_health_provider.dart | lib/core/providers/backend_health_provider.dart |
| backend_version_provider.dart | lib/core/providers/backend_version_provider.dart |
| infrastructure_providers.dart | lib/core/providers/infrastructure_providers.dart |
| backend_versions_screen.dart | lib/features/settings/backend_versions_screen.dart |

---

## 04 - Active Run & Streaming (6 files)

| File | Path |
|------|------|
| active_run_state.dart | lib/core/models/active_run_state.dart |
| filter_documents.dart | lib/core/models/agui_features/filter_documents.dart |
| active_run_notifier.dart | lib/core/providers/active_run_notifier.dart |
| active_run_provider.dart | lib/core/providers/active_run_provider.dart |
| run_lifecycle_impl.dart | lib/core/application/run_lifecycle_impl.dart |
| run_lifecycle.dart | lib/core/domain/interfaces/run_lifecycle.dart |

---

## 05 - Thread Management (5 files)

| File | Path |
|------|------|
| thread_history_cache.dart | lib/core/providers/thread_history_cache.dart |
| threads_provider.dart | lib/core/providers/threads_provider.dart |
| history_panel.dart | lib/features/history/history_panel.dart |
| new_conversation_button.dart | lib/features/history/widgets/new_conversation_button.dart |
| thread_list_item.dart | lib/features/history/widgets/thread_list_item.dart |

---

## 06 - Room Management (6 files)

| File | Path |
|------|------|
| rooms_provider.dart | lib/core/providers/rooms_provider.dart |
| room_screen.dart | lib/features/room/room_screen.dart |
| rooms_screen.dart | lib/features/rooms/rooms_screen.dart |
| room_grid_card.dart | lib/features/rooms/widgets/room_grid_card.dart |
| room_list_tile.dart | lib/features/rooms/widgets/room_list_tile.dart |
| room_search_toolbar.dart | lib/features/rooms/widgets/room_search_toolbar.dart |

---

## 07 - Document Selection (2 files)

| File | Path |
|------|------|
| documents_provider.dart | lib/core/providers/documents_provider.dart |
| selected_documents_provider.dart | lib/core/providers/selected_documents_provider.dart |

---

## 08 - Chat UI (11 files)

| File | Path |
|------|------|
| chunk_visualization_provider.dart | lib/core/providers/chunk_visualization_provider.dart |
| citations_expanded_provider.dart | lib/core/providers/citations_expanded_provider.dart |
| source_references_provider.dart | lib/core/providers/source_references_provider.dart |
| chat_panel.dart | lib/features/chat/chat_panel.dart |
| chat_input.dart | lib/features/chat/widgets/chat_input.dart |
| chat_message_widget.dart | lib/features/chat/widgets/chat_message_widget.dart |
| chunk_visualization_page.dart | lib/features/chat/widgets/chunk_visualization_page.dart |
| citations_section.dart | lib/features/chat/widgets/citations_section.dart |
| code_block_builder.dart | lib/features/chat/widgets/code_block_builder.dart |
| message_list.dart | lib/features/chat/widgets/message_list.dart |
| status_indicator.dart | lib/features/chat/widgets/status_indicator.dart |

---

## 09 - HTTP Inspector (8 files)

| File | Path |
|------|------|
| http_log_provider.dart | lib/core/providers/http_log_provider.dart |
| http_inspector_panel.dart | lib/features/inspector/http_inspector_panel.dart |
| http_event_group.dart | lib/features/inspector/models/http_event_group.dart |
| http_event_grouper.dart | lib/features/inspector/models/http_event_grouper.dart |
| network_inspector_screen.dart | lib/features/inspector/network_inspector_screen.dart |
| http_event_tile.dart | lib/features/inspector/widgets/http_event_tile.dart |
| http_status_display.dart | lib/features/inspector/widgets/http_status_display.dart |
| request_detail_view.dart | lib/features/inspector/widgets/request_detail_view.dart |

---

## 10 - Configuration (8 files)

| File | Path |
|------|------|
| app_config.dart | lib/core/models/app_config.dart |
| features.dart | lib/core/models/features.dart |
| logo_config.dart | lib/core/models/logo_config.dart |
| route_config.dart | lib/core/models/route_config.dart |
| soliplex_config.dart | lib/core/models/soliplex_config.dart |
| theme_config.dart | lib/core/models/theme_config.dart |
| config_provider.dart | lib/core/providers/config_provider.dart |
| shell_config_provider.dart | lib/core/providers/shell_config_provider.dart |

---

## 11 - Design System (10 files)

| File | Path |
|------|------|
| design.dart | lib/design/design.dart |
| color_scheme_extensions.dart | lib/design/color/color_scheme_extensions.dart |
| theme.dart | lib/design/theme/theme.dart |
| theme_extensions.dart | lib/design/theme/theme_extensions.dart |
| breakpoints.dart | lib/design/tokens/breakpoints.dart |
| colors.dart | lib/design/tokens/colors.dart |
| radii.dart | lib/design/tokens/radii.dart |
| spacing.dart | lib/design/tokens/spacing.dart |
| typography.dart | lib/design/tokens/typography.dart |
| typography_x.dart | lib/design/tokens/typography_x.dart |

---

## 12 - Shared Widgets (7 files)

| File | Path |
|------|------|
| app_shell.dart | lib/shared/widgets/app_shell.dart |
| async_value_handler.dart | lib/shared/widgets/async_value_handler.dart |
| empty_state.dart | lib/shared/widgets/empty_state.dart |
| error_display.dart | lib/shared/widgets/error_display.dart |
| loading_indicator.dart | lib/shared/widgets/loading_indicator.dart |
| platform_adaptive_progress_indicator.dart | lib/shared/widgets/platform_adaptive_progress_indicator.dart |
| shell_config.dart | lib/shared/widgets/shell_config.dart |

---

## 13 - Client: Domain Models (17 files)

| File | Path |
|------|------|
| auth_provider_config.dart | packages/soliplex_client/lib/src/domain/auth_provider_config.dart |
| backend_version_info.dart | packages/soliplex_client/lib/src/domain/backend_version_info.dart |
| chat_message.dart | packages/soliplex_client/lib/src/domain/chat_message.dart |
| chunk_visualization.dart | packages/soliplex_client/lib/src/domain/chunk_visualization.dart |
| citation_formatting.dart | packages/soliplex_client/lib/src/domain/citation_formatting.dart |
| conversation.dart | packages/soliplex_client/lib/src/domain/conversation.dart |
| domain.dart | packages/soliplex_client/lib/src/domain/domain.dart |
| message_state.dart | packages/soliplex_client/lib/src/domain/message_state.dart |
| quiz.dart | packages/soliplex_client/lib/src/domain/quiz.dart |
| rag_document.dart | packages/soliplex_client/lib/src/domain/rag_document.dart |
| room.dart | packages/soliplex_client/lib/src/domain/room.dart |
| run_info.dart | packages/soliplex_client/lib/src/domain/run_info.dart |
| source_reference.dart | packages/soliplex_client/lib/src/domain/source_reference.dart |
| thread_history.dart | packages/soliplex_client/lib/src/domain/thread_history.dart |
| thread_info.dart | packages/soliplex_client/lib/src/domain/thread_info.dart |
| ask_history.dart | packages/soliplex_client/lib/src/schema/agui_features/ask_history.dart |
| haiku_rag_chat.dart | packages/soliplex_client/lib/src/schema/agui_features/haiku_rag_chat.dart |

---

## 14 - Client: HTTP Layer (13 files)

| File | Path |
|------|------|
| soliplex_client.dart | packages/soliplex_client/lib/soliplex_client.dart |
| authenticated_http_client.dart | packages/soliplex_client/lib/src/http/authenticated_http_client.dart |
| dart_http_client.dart | packages/soliplex_client/lib/src/http/dart_http_client.dart |
| http.dart | packages/soliplex_client/lib/src/http/http.dart |
| http_client_adapter.dart | packages/soliplex_client/lib/src/http/http_client_adapter.dart |
| http_observer.dart | packages/soliplex_client/lib/src/http/http_observer.dart |
| http_redactor.dart | packages/soliplex_client/lib/src/http/http_redactor.dart |
| http_response.dart | packages/soliplex_client/lib/src/http/http_response.dart |
| http_transport.dart | packages/soliplex_client/lib/src/http/http_transport.dart |
| observable_http_client.dart | packages/soliplex_client/lib/src/http/observable_http_client.dart |
| refreshing_http_client.dart | packages/soliplex_client/lib/src/http/refreshing_http_client.dart |
| soliplex_http_client.dart | packages/soliplex_client/lib/src/http/soliplex_http_client.dart |
| token_refresher.dart | packages/soliplex_client/lib/src/http/token_refresher.dart |

---

## 15 - Client: API Endpoints (5 files)

| File | Path |
|------|------|
| agui_message_mapper.dart | packages/soliplex_client/lib/src/api/agui_message_mapper.dart |
| api.dart | packages/soliplex_client/lib/src/api/api.dart |
| fetch_auth_providers.dart | packages/soliplex_client/lib/src/api/fetch_auth_providers.dart |
| mappers.dart | packages/soliplex_client/lib/src/api/mappers.dart |
| soliplex_api.dart | packages/soliplex_client/lib/src/api/soliplex_api.dart |

---

## 16 - Client: Application (5 files)

| File | Path |
|------|------|
| agui_event_processor.dart | packages/soliplex_client/lib/src/application/agui_event_processor.dart |
| application.dart | packages/soliplex_client/lib/src/application/application.dart |
| citation_extractor.dart | packages/soliplex_client/lib/src/application/citation_extractor.dart |
| json_patch.dart | packages/soliplex_client/lib/src/application/json_patch.dart |
| streaming_state.dart | packages/soliplex_client/lib/src/application/streaming_state.dart |

---

## 17 - Client: Utilities (7 files)

| File | Path |
|------|------|
| date_formatter.dart | lib/shared/utils/date_formatter.dart |
| format_utils.dart | lib/shared/utils/format_utils.dart |
| errors.dart | packages/soliplex_client/lib/src/errors/errors.dart |
| exceptions.dart | packages/soliplex_client/lib/src/errors/exceptions.dart |
| cancel_token.dart | packages/soliplex_client/lib/src/utils/cancel_token.dart |
| url_builder.dart | packages/soliplex_client/lib/src/utils/url_builder.dart |
| utils.dart | packages/soliplex_client/lib/src/utils/utils.dart |

---

## 18 - Native Platform (11 files)

| File | Path |
|------|------|
| screen_wake_lock.dart | lib/core/domain/interfaces/screen_wake_lock.dart |
| wakelock_plus_adapter.dart | lib/core/infrastructure/platform/wakelock_plus_adapter.dart |
| platform_resolver.dart | lib/shared/utils/platform_resolver.dart |
| soliplex_client_native.dart | packages/soliplex_client_native/lib/soliplex_client_native.dart |
| clients.dart | packages/soliplex_client_native/lib/src/clients/clients.dart |
| cupertino_http_client.dart | packages/soliplex_client_native/lib/src/clients/cupertino_http_client.dart |
| cupertino_http_client_stub.dart | packages/soliplex_client_native/lib/src/clients/cupertino_http_client_stub.dart |
| create_platform_client.dart | packages/soliplex_client_native/lib/src/platform/create_platform_client.dart |
| create_platform_client_io.dart | packages/soliplex_client_native/lib/src/platform/create_platform_client_io.dart |
| create_platform_client_stub.dart | packages/soliplex_client_native/lib/src/platform/create_platform_client_stub.dart |
| platform.dart | packages/soliplex_client_native/lib/src/platform/platform.dart |

---

## 19 - Navigation & Routing (1 file)

| File | Path |
|------|------|
| app_router.dart | lib/core/router/app_router.dart |

---

## 20 - Quiz Feature (2 files)

| File | Path |
|------|------|
| quiz_provider.dart | lib/core/providers/quiz_provider.dart |
| quiz_screen.dart | lib/features/quiz/quiz_screen.dart |

---

## Summary by Domain

| # | Domain | Files |
|---|--------|-------|
| 01 | App Shell & Entry | 8 |
| 02 | Authentication Flow | 19 |
| 03 | State Management Core | 5 |
| 04 | Active Run & Streaming | 6 |
| 05 | Thread Management | 5 |
| 06 | Room Management | 6 |
| 07 | Document Selection | 2 |
| 08 | Chat UI | 11 |
| 09 | HTTP Inspector | 8 |
| 10 | Configuration | 8 |
| 11 | Design System | 10 |
| 12 | Shared Widgets | 7 |
| 13 | Client: Domain Models | 17 |
| 14 | Client: HTTP Layer | 13 |
| 15 | Client: API Endpoints | 5 |
| 16 | Client: Application | 5 |
| 17 | Client: Utilities | 7 |
| 18 | Native Platform | 11 |
| 19 | Navigation & Routing | 1 |
| 20 | Quiz Feature | 2 |
| **Total** | | **156** |

---

## Notes

- Test files documented separately in Phase 2
