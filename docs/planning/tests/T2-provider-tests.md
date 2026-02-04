# T2 - Provider Tests

## Overview

Comprehensive test coverage for Riverpod state management providers including API client
initialization, configuration, threads, rooms, documents, active runs, and HTTP logging.

## Test Files (16)

| Location | File | Test Count |
|----------|------|------------|
| App | `test/core/providers/api_provider_test.dart` | 16 |
| App | `test/core/providers/config_provider_test.dart` | 14 |
| App | `test/core/providers/shell_config_provider_test.dart` | 3 |
| App | `test/core/providers/active_run_provider_test.dart` | 6 |
| App | `test/core/providers/active_run_notifier_test.dart` | 24 |
| App | `test/core/providers/threads_provider_test.dart` | 16 |
| App | `test/core/providers/last_viewed_thread_test.dart` | 8 |
| App | `test/core/providers/thread_history_cache_test.dart` | 9 |
| App | `test/core/providers/rooms_provider_test.dart` | 8 |
| App | `test/core/providers/selected_documents_provider_test.dart` | 6 |
| App | `test/core/providers/citations_expanded_provider_test.dart` | 4 |
| App | `test/core/providers/chunk_visualization_provider_test.dart` | 3 |
| App | `test/core/providers/source_references_provider_test.dart` | 4 |
| App | `test/core/providers/http_log_provider_test.dart` | 9 |
| App | `test/core/providers/quiz_provider_test.dart` | 14 |
| App | `test/core/application/run_lifecycle_impl_test.dart` | 4 |

## Test Utilities

| Utility | Purpose |
|---------|---------|
| `MockSoliplexApi` | API call simulation |
| `MockAgUiClient` | Streaming client mock |
| `CloseTrackingHttpClient` | Verify close() invocations |
| `CloseCountingHttpClient` | Count close() calls |
| `MockRunLifecycle` | Lifecycle hook mock |
| `MockScreenWakeLock` | Wake lock mock |
| `SharedPreferences.setMockInitialValues` | Storage mocking |
| `TestData` | Factory for test fixtures |
| `createContainerWithMockedAuth` | ProviderContainer builder |
| `waitForAuthRestore` | Async auth helper |

## Test Coverage by Domain

### API Provider (`api_provider_test.dart`)

**httpTransportProvider:**

| Test Case | Verifies |
|-----------|----------|
| creates HttpTransport instance | Correct type creation |
| is singleton across multiple reads | Instance stability |
| container disposal completes | Cleanup stability |

**urlBuilderProvider:**

| Test Case | Verifies |
|-----------|----------|
| creates UrlBuilder with base URL from config | Config integration |
| uses different baseUrl for different config | Config responsiveness |

**apiProvider:**

| Test Case | Verifies |
|-----------|----------|
| creates SoliplexApi instance | Type creation |
| is singleton across multiple reads | Instance stability |
| shares transport with agUiClientProvider | Shared client dependency |
| container disposal completes | Cleanup stability |
| creates different instances for different configs | Config responsiveness |

**authenticatedClientProvider:**

| Test Case | Verifies |
|-----------|----------|
| creates SoliplexHttpClient instance | Authenticated wrapper creation |
| is singleton across multiple reads | Instance stability |
| initializes HttpLogNotifier dependency | Logging system startup |

**Resource Ownership (Regression #27):**

| Test Case | Verifies |
|-----------|----------|
| agUiClientProvider disposal does not close shared httpClient | Safe provider disposal |
| httpClientProvider invalidation preserves soliplexClient | Invalidation safety |
| multiple config changes do not cause cumulative close() | Rapid config change safety |

### Config Provider (`config_provider_test.dart`)

**ConfigNotifier:**

| Test Case | Verifies |
|-----------|----------|
| build returns platform default when no config URL | Fallback to localhost |
| build returns shellConfigProvider URL when overridden | Shell config priority |
| build returns preloaded URL when available | Preloaded URL priority |
| setBaseUrl persists URL to SharedPreferences | Storage logic |
| setBaseUrl updates state | Riverpod state update |
| setBaseUrl trims whitespace | Input sanitization |
| setBaseUrl ignores empty URL | Input validation |
| setBaseUrl ignores same URL | Change optimization |
| set directly updates state | Direct object setting |

**URL Priority Chain:**

| Test Case | Verifies |
|-----------|----------|
| preloaded URL has highest priority | Precedence level 1 |
| explicit config URL has second priority | Precedence level 2 |
| platform default is lowest priority | Precedence level 3 |

### Shell Config Provider (`shell_config_provider_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| throws when not overridden | Required override validation |
| provides config when overridden | Successful retrieval |
| featuresProvider provides features | Feature extraction |

### Active Run Provider (`active_run_provider_test.dart`)

**allMessagesProvider:**

| Test Case | Verifies |
|-----------|----------|
| messages persist in cache after switching threads | Thread switch preservation |
| cache persists messages when run completes | History persistence |
| deduplicates messages by ID | Cached version preferred |
| preserves order | Cached first, then running |
| returns empty list when no thread/room | Null safety |

### Active Run Notifier (`active_run_notifier_test.dart`)

**State Management:**

| Test Case | Verifies |
|-----------|----------|
| initial state is IdleState | Correct initialization |
| reset returns to IdleState | Reset behavior |
| reset idempotency | Multiple reset safety |
| state type checks (isRunning) | State classification |
| convenience getters | Delegation correctness |

**startRun:**

| Test Case | Verifies |
|-----------|----------|
| displays user message immediately | Optimistic UI |
| transitions to RunningState | State transition |
| uses existingRunId | Join existing runs |
| throws if run already active | State machine protection |
| concurrent startRun protection | Double-invocation guard |

**cancelRun:**

| Test Case | Verifies |
|-----------|----------|
| transitions to CompletedState with Cancelled | Cancellation logic |
| preserves messages | Message visibility |

**Thread Change:**

| Test Case | Verifies |
|-----------|----------|
| resets state when switching threads | Context switch cleanup |
| does not reset when selecting same thread | Optimization |

**Events & Cache:**

| Test Case | Verifies |
|-----------|----------|
| updates cache when RUN_FINISHED | Success persistence |
| updates cache when RUN_ERROR | Failure persistence |
| stream error handling | Failed state transition |
| stream onDone without finished event | Implicit completion |
| includes cached messages in Conversation | Context merging |
| sends complete history to backend | Full context transmission |
| CancellationError | Dart cancellation handling |

**RunLifecycle Integration:**

| Test Case | Verifies |
|-----------|----------|
| calls onRunStarted | Lifecycle hook |
| calls onRunEnded | Lifecycle hook on finish/error/cancel/reset |

### Threads Provider (`threads_provider_test.dart`)

**threadsProvider:**

| Test Case | Verifies |
|-----------|----------|
| returns list of threads from API | Fetch logic |
| propagates NotFoundException/NetworkException/ApiException | Error handling |
| caches threads separately per room | Family isolation |
| can be refreshed per room | Refresh logic |
| returns empty list when room has no threads | Empty state |
| sorts threads by createdAt descending | Newest first |
| sorts by id when createdAt equal | Deterministic sorting |

**threadSelectionProvider:**

| Test Case | Verifies |
|-----------|----------|
| starts with NoThreadSelected | Initial state |
| can be updated to ThreadSelected/NewThreadIntent | State changes |

### Last Viewed Thread (`last_viewed_thread_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| returns NoLastViewed/HasLastViewed | State retrieval |
| returns different threads for different rooms | Data isolation |
| saves thread id to SharedPreferences | Persistence |
| overwrites previous value | Update logic |
| does not affect other rooms | Namespace isolation |
| invalidates lastViewedThreadProvider | Reactive updates |
| clearLastViewedThread removes data | Deletion |
| invalidateLastViewed creates working callback | Widget invalidation |

### Thread History Cache (`thread_history_cache_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| returns cached history on hit | No API call if cached |
| fetches from API and caches on miss | API call and storage |
| subsequent calls use cache | Caching effectiveness |
| concurrent fetches share single API request | Request coalescing |
| propagates API errors wrapped | HistoryFetchException |
| allows retry after API error | Error not permanently cached |
| different threads have separate cache entries | Isolation |
| updateHistory updates cache | Manual mutation |
| refreshHistory clears and refetches | Forced refresh |

### Rooms Provider (`rooms_provider_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| returns list of rooms from API | Fetch logic |
| propagates NetworkException/AuthException/ApiException | Error propagation |
| can be refreshed | Refresh capability |
| returns empty list | Empty handling |
| currentRoomIdProvider starts null/can update | State holding |
| currentRoomProvider returns null/selected room | Derivation |
| returns null when room not found/loading | Safety |

### Selected Documents Provider (`selected_documents_provider_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| setForThread/getForThread | CRUD operations |
| different threads/rooms independent | Data isolation |
| clearForThread/clearForRoom | Scoped removal |
| currentSelectedDocumentsProvider derivation | Reactivity |
| updates when thread selection changes | State binding |

### Citations Expanded Provider (`citations_expanded_provider_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| initial state is empty set | Default state |
| toggle adds/removes key | Toggle logic |
| multiple keys tracked independent | Set behavior |
| state is immutable | Riverpod compliance |

### Chunk Visualization Provider (`chunk_visualization_provider_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| fetches chunk visualization from API | Data retrieval |
| uses correct parameters | API arguments |
| caches result | No duplicate API calls |

### Source References Provider (`source_references_provider_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| returns empty list when userMessageId null | Null check |
| returns from active run | ActiveRunNotifier retrieval |
| returns from cache | ThreadHistoryCache retrieval |
| prefers active run over cache | Priority logic |

### HTTP Log Provider (`http_log_provider_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| implements HttpObserver | Interface compliance |
| onRequest/onResponse/onError/onStreamStart/onStreamEnd | Event recording |
| event ordering | Chronological sorting |
| clear | List clearing |
| event passthrough | Headers/bodies stored |
| event cap | maxEvents limit |
| drops oldest events | FIFO overflow |

### Quiz Provider (`quiz_provider_test.dart`)

**quizProvider:**

| Test Case | Verifies |
|-----------|----------|
| returns quiz from API | Fetch logic |
| propagates NotFoundException | Error handling |
| caches quizzes separately | Per-room/quiz isolation |

**quizSessionProvider:**

| Test Case | Verifies |
|-----------|----------|
| start transitions to QuizInProgress | State transition |
| submitAnswer calls API, updates results | API integration |
| nextQuestion increments or completes | Navigation |
| reset/retake resets state | State reset |
| updateInput transitions to Composing/Answered | Input tracking |
| throws on empty input | Validation |
| throws on invalid state transitions | State machine |
| ignores input while submitting | Concurrency |
| handles reset during API flight | Graceful cancellation |
| isolates state per quiz key | Instance isolation |

### Run Lifecycle (`run_lifecycle_impl_test.dart`)

| Test Case | Verifies |
|-----------|----------|
| single run enable/disable wake lock | Basic lifecycle |
| multiple concurrent runs reference counting | Lock stays until all end |
| idempotency | Duplicate calls safe |
| ending unknown runs doesn't crash | Edge case safety |

## Testing Patterns

- **Family Provider Isolation**: Verified per-room/per-thread data separation
- **Request Coalescing**: Concurrent fetches share single API request
- **Resource Ownership**: Provider disposal doesn't close shared resources
- **State Machine Validation**: Invalid transitions throw exceptions
- **Optimistic Updates**: UI updates before API completion
- **Reference Counting**: Wake lock managed across concurrent runs
