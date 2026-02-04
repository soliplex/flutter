# T4 - Client Package Tests

## Overview

Comprehensive test coverage for the `soliplex_client` package including domain models,
HTTP client stack, API layer, application services, and utility classes.

## Test Files (34)

### Domain Models (15)

| File | Test Count |
|------|------------|
| `test/domain/auth_provider_config_test.dart` | 7 |
| `test/domain/backend_version_info_test.dart` | 9 |
| `test/domain/chat_message_test.dart` | 30 |
| `test/domain/chunk_visualization_test.dart` | 12 |
| `test/domain/citation_test.dart` | 9 |
| `test/domain/citation_formatting_test.dart` | 10 |
| `test/domain/conversation_test.dart` | 18 |
| `test/domain/message_state_test.dart` | 4 |
| `test/domain/quiz_test.dart` | 20 |
| `test/domain/rag_document_test.dart` | 6 |
| `test/domain/room_test.dart` | 9 |
| `test/domain/run_info_test.dart` | 21 |
| `test/domain/source_reference_test.dart` | 17 |
| `test/domain/thread_history_test.dart` | 7 |
| `test/domain/thread_info_test.dart` | 9 |

### HTTP Layer (9)

| File | Test Count |
|------|------------|
| `test/http/authenticated_http_client_test.dart` | 12 |
| `test/http/dart_http_client_test.dart` | 25 |
| `test/http/http_client_adapter_test.dart` | 6 |
| `test/http/http_observer_test.dart` | 8 |
| `test/http/http_redactor_test.dart` | 10 |
| `test/http/http_response_test.dart` | 8 |
| `test/http/http_transport_test.dart` | 18 |
| `test/http/observable_http_client_test.dart` | 10 |
| `test/http/refreshing_http_client_test.dart` | 6 |

### API Layer (4)

| File | Test Count |
|------|------------|
| `test/api/fetch_auth_providers_test.dart` | 5 |
| `test/api/agui_message_mapper_test.dart` | 6 |
| `test/api/mappers_test.dart` | 12 |
| `test/api/soliplex_api_test.dart` | 20 |

### Application Services (4)

| File | Test Count |
|------|------------|
| `test/application/agui_event_processor_test.dart` | 30 |
| `test/application/citation_extractor_test.dart` | 11 |
| `test/application/json_patch_test.dart` | 22 |
| `test/application/streaming_state_test.dart` | 7 |

### Utilities (2)

| File | Test Count |
|------|------------|
| `test/utils/url_builder_test.dart` | 8 |
| `test/errors/exceptions_test.dart` | 6 |

## Test Utilities

| Utility | Purpose |
|---------|---------|
| `MockSoliplexHttpClient` | HTTP client mock |
| `MockHttpTransport` | Transport layer mock |
| `MockHttpClient` | dart:http package mock |
| `MockTokenRefresher` | Token refresh mock |
| `FakeTokenRefresher` | Real async concurrency testing |
| `FakeHttpClient` | Controllable HTTP responses |
| `_RecordingObserver` | Event capture |
| `ThrowingObserver` | Error resilience testing |

## Test Coverage by Domain

### AuthProviderConfig (`auth_provider_config_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| creates with required fields | Constructor assignment |
| equality when attributes match | Value equality |
| not equal when any attribute differs | Inequality detection |
| hashCode consistency | Hash based on all fields |
| toString includes id and name | String representation |

### BackendVersionInfo (`backend_version_info_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| creates with required/empty fields | Constructor assignment |
| equality based on all fields | Value equality |
| hashCode when objects equal | Hash consistency |
| toString format | String representation |

### ChatMessage (`chat_message_test.dart`)

**TextMessage:**

| Test Case | Verifies |
|-----------|----------|
| create with required/all fields | Constructor assignment |
| copyWith modifies fields | Immutable updates |
| equality by id | Entity equality |
| hasThinkingText | Computed property |

**Sealed Class Variants:**

| Test Case | Verifies |
|-----------|----------|
| ErrorMessage/ToolCallMessage/GenUiMessage/LoadingMessage | Construction and equality |
| different types with same id not equal | Type discrimination |
| pattern matching | Dart 3 switch expressions |

**ToolCallInfo:**

| Test Case | Verifies |
|-----------|----------|
| creates with fields | Constructor |
| copyWith | Immutable updates |
| hasArguments/hasResult | Computed properties |

### ChunkVisualization (`chunk_visualization_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| creates with required/null fields | Constructor |
| fromJson/toJson | JSON serialization |
| roundtrip preservation | Full cycle integrity |
| hasImages/imageCount | Computed properties |
| equality | Value equality |

### Citation (`citation_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| creates with required/all fields | Constructor |
| fromJson handles missing/empty | Resilient parsing |
| toJson serialization | Output format |
| roundtrip preservation | Full cycle integrity |
| headings/index fields | List/integer handling |

### Citation Formatting (`citation_formatting_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| formattedPageNumbers null/empty | Null handling |
| formattedPageNumbers single/range/comma | Format logic |
| formattedPageNumbers sorting | Pre-format sorting |
| displayTitle priority | Title > URI > fallback |
| isPdf | Extension detection |

### Conversation (`conversation_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| empty creates defaults | Factory constructor |
| withAppendedMessage | Message addition |
| withToolCall | Tool call addition |
| withStatus | Status transitions |
| copyWith | Immutable updates |
| equality | Deep equality |
| messageStates | Message-specific state |

**ConversationStatus:**

| Test Case | Verifies |
|-----------|----------|
| Idle/Running/Completed/Failed/Cancelled | Value semantics |
| isRunning | Active state detection |

### MessageState (`message_state_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| creates with empty/populated refs | Constructor |
| equality | Value equality |
| immutability | List defensive copy |

### Quiz (`quiz_test.dart`)

**QuestionLimit:**

| Test Case | Verifies |
|-----------|----------|
| AllQuestions/LimitedQuestions | Construction |
| throws for 0/negative count | Validation |
| equality/hashCode | Value semantics |

**QuestionType:**

| Test Case | Verifies |
|-----------|----------|
| MultipleChoice/FillBlank/FreeForm | Construction |
| options unmodifiable | List defensive copy |
| throws for <2 options | Validation |

**Quiz/QuizQuestion:**

| Test Case | Verifies |
|-----------|----------|
| creates with fields | Construction |
| hasQuestions/questionCount | Computed properties |
| equality by id | Entity equality |

**QuizAnswerResult:**

| Test Case | Verifies |
|-----------|----------|
| CorrectAnswer/IncorrectAnswer | Value semantics |
| isCorrect | Computed property |

### RagDocument (`rag_document_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| creates with required fields | Construction |
| equality by id | Entity equality |
| hashCode based on id | Hash |
| copyWith | Immutable updates |

### Room (`room_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| creates with required/all fields | Constructor |
| copyWith | Immutable updates |
| equality by id | Entity equality |
| hashCode based on id | Hash |
| hasDescription helpers | Boolean computed properties |

### RunInfo (`run_info_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| creates with required/all fields | Constructor |
| copyWith | Immutable updates |
| equality by id only | Entity equality |
| CompletedAt/NotCompleted | Completion time wrapper |
| RunStatus enum values | All 6 states |

### SourceReference (`source_reference_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| creates with required/all fields | Constructor |
| equality based on chunkId | Discriminator |
| formattedPageNumbers | Format logic |
| displayTitle priority | Title > URI > fallback |
| isPdf | Extension detection |

### ThreadHistory (`thread_history_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| constructs with messages/state | Constructor |
| aguiState defaults empty | Default value |
| immutability | List/map defensive copy |
| messageStates | Message-specific state |

### ThreadInfo (`thread_info_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| creates with required/all fields | Constructor |
| copyWith | Immutable updates |
| equality by id only | Entity equality |
| hashCode based on id | Hash |

### Authenticated HTTP Client (`authenticated_http_client_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| injects Authorization header | Token injection |
| skips header when token null | Null handling |
| calls token provider per request | Dynamic tokens |
| preserves existing headers | Header merging |
| forwards to requestStream | Stream support |
| delegates close() | Resource cleanup |
| propagates exceptions | Error passthrough |

### Dart HTTP Client (`dart_http_client_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| GET/POST/PUT/DELETE/PATCH/HEAD | Method support |
| Map/String/Bytes bodies | Body types |
| custom headers | Header handling |
| content-type override | User precedence |
| NetworkException on timeout | isTimeout flag |
| NetworkException on SocketException | Error wrapping |
| requestStream chunks | Streaming support |
| NetworkException on non-200 streams | Stream errors |
| cancellation via subscription | Stream control |
| close idempotency | Safe cleanup |

### HTTP Client Adapter (`http_client_adapter_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| delegates standard requests | GET/POST forwarding |
| returns status/headers/length | Response mapping |
| delegates SSE requests | text/event-stream detection |
| streams data chunks | Chunk forwarding |
| observability integration | Event recording |

### HTTP Observer Events (`http_observer_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| HttpRequestEvent creation/equality | Data class |
| HttpResponseEvent isSuccess | 2xx detection |
| HttpErrorEvent creation | Exception wrapping |
| HttpStreamStart/EndEvent | Stream lifecycle |

### HTTP Redactor (`http_redactor_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| redacts Authorization/Cookie/X-API-Key | Exact matches |
| redacts token/secret/password keys | Substring matches |
| preserves Content-Type/User-Agent | Non-sensitive |
| case-insensitive matching | Header normalization |
| redacts sensitive query params | URI redaction |
| redacts JSON body fields | Deep redaction |
| auth endpoint full body redaction | /login, /oauth, /token |

### HTTP Response (`http_response_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| construction and body getter | UTF-8 decoding |
| isSuccess/isRedirect/isClientError/isServerError | Status helpers |
| contentType/contentLength | Header helpers |

### HTTP Transport (`http_transport_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| parses JSON to Map/List | Response parsing |
| uses fromJson converter | Custom parsing |
| returns raw String for non-JSON | Text responses |
| forwards methods | GET/POST/PUT/DELETE/PATCH |
| injects application/json | Map body handling |
| maps 401/403 to AuthException | Error mapping |
| maps 404 to NotFoundException | Error mapping |
| maps 400/500/502 to ApiException | Error mapping |
| extracts error messages | JSON body parsing |
| CancelToken throws CancelledException | Cancellation |
| stream cancellation | Mid-flight cancel |

### Observable HTTP Client (`observable_http_client_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| emits Request/Response events | Lifecycle tracking |
| emits Error event | Error tracking |
| emits StreamStart/End events | Stream lifecycle |
| tracks bytes received | Stream metrics |
| buffers SSE content | Content capture |
| observer exceptions don't crash | Resilience |
| correlates via requestId | Event linking |

### Refreshing HTTP Client (`refreshing_http_client_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| proactive refresh | refreshIfExpiringSoon |
| 401 retry | Single retry |
| prevents infinite loops | No second retry |
| deduplicates refresh calls | Concurrency |
| propagates refresh failures | Error handling |
| no retry on streams | Stream limitation |

### Fetch Auth Providers (`fetch_auth_providers_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| parses provider list | keycloak, pydio types |
| handles empty lists | Empty state |
| handles trailing slashes | URL normalization |
| propagates exceptions | Error passthrough |

### AgUI Message Mapper (`agui_message_mapper_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| maps User/Assistant/System | Text conversion |
| maps ToolCallMessage | Tool call + result |
| handles pending vs completed | State awareness |
| maps GenUiMessage | Widget description |
| filters Error/Loading | Skip logic |

### API Mappers (`mappers_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| BackendVersionInfo parsing | Version strings |
| Room parse/serialize | Full cycle |
| RagDocument parse/serialize | RAG references |
| ThreadInfo parsing | Timestamps |
| RunInfo parsing | Status/completion |
| Quiz question types | MultipleChoice/FillBlank/FreeForm |
| QuestionLimit/QuizAnswerResult | Sub-models |

### Soliplex API (`soliplex_api_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| cache cleared on close | Resource cleanup |
| CRUD operations | getRooms/getRoom/getThreads/createThread/etc |
| thread history fetching | Run metadata + events |
| parallel event fetching | Performance optimization |
| run event caching | LRU cache |
| merging user messages | run_input + events |
| STATE_SNAPSHOT parsing | Citation/source refs |
| partial fetch failure | onWarning callback |
| chunk visualization | RAG chunk data |
| installation info | Version fetching |

### AgUI Event Processor (`agui_event_processor_test.dart`)

**Run Lifecycle:**

| Test Case | Verifies |
|-----------|----------|
| RunStartedEvent sets Running | Status transition |
| RunFinishedEvent sets Completed | Status transition |
| RunErrorEvent sets Failed | Error handling |

**Text Streaming:**

| Test Case | Verifies |
|-----------|----------|
| TextMessageStartEvent begins streaming | State initialization |
| TextMessageContentEvent appends delta | Concatenation |
| TextMessageContentEvent ignores mismatched ID | Guard |
| TextMessageEndEvent finalizes message | History append |

**Tool Calls:**

| Test Case | Verifies |
|-----------|----------|
| ToolCallStartEvent adds to list | Accumulation |
| ToolCallEndEvent removes from list | Cleanup |
| multiple tools accumulate | Activity tracking |

**Thinking Events:**

| Test Case | Verifies |
|-----------|----------|
| ThinkingTextMessageStartEvent sets mode | State flag |
| ThinkingTextMessageContentEvent buffers | Pre-stream buffer |
| TextMessageStartEvent transfers buffer | Handoff |
| TextMessageEndEvent preserves thinkingText | Final message |

**State Events:**

| Test Case | Verifies |
|-----------|----------|
| StateSnapshotEvent replaces state | Full replacement |
| StateDeltaEvent applies JSON Patch | Incremental update |

### Citation Extractor (`citation_extractor_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| returns empty when no change | Idempotency |
| extracts from new qa_history | Parsing |
| extracts only new entries | Diff logic |
| handles entry with no citations | Null safety |
| supports ask_history format | Legacy support |
| prefers haiku.rag.chat | Format precedence |
| handles unknown format | Graceful degradation |

### JSON Patch (`json_patch_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| add at root/nested | Key creation |
| add to array | Append logic |
| RFC 6902 "-" syntax | Standard append |
| replace existing/nested | Update logic |
| remove at root/nested/array | Deletion |
| multiple operations | Batch processing |
| skips invalid operations | Error handling |
| immutability | Deep copy |
| edge cases | Empty path, invalid index |

### Streaming State (`streaming_state_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| ToolCallActivity.withToolName accumulates | Set addition |
| idempotent for duplicates | Set behavior |
| equality across constructors | Value semantics |
| AwaitingText.hasThinkingContent | Computed property |

### URL Builder (`url_builder_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| constructs with schemes | HTTP/HTTPS |
| appends paths/segments | Slash handling |
| encodes query params | URL encoding |
| handles ports/subpaths | Base URL variations |

### Exceptions (`exceptions_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| inherits from SoliplexException | Type hierarchy |
| toString formatting | All exception types |
| stores original errors | Error wrapping |
| stores stack traces | Debug info |
| stores status codes | API error context |

## Testing Patterns

- **Value Equality**: Domain models tested for proper `==` and `hashCode`
- **Entity Equality**: ID-based equality for Room, Thread, Run, etc.
- **Immutability**: copyWith and defensive copy verification
- **JSON Roundtrip**: fromJson/toJson cycle integrity
- **Error Mapping**: HTTP status → typed exceptions
- **Concurrency**: Token refresh deduplication
- **Streaming**: Chunk delivery and cancellation
- **Security**: Header/body redaction, SSRF protection
