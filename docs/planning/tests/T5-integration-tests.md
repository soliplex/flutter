# T5 - Contract & Integration Tests

## Overview

Contract tests verify public API stability and schema compatibility. These tests prevent
breaking changes and ensure generated types match backend contracts.

## Test Files (5)

| Location | File | Purpose |
|----------|------|---------|
| App | `test/api_contract/soliplex_frontend_contract_test.dart` | Frontend public API |
| Client | `test/api_contract/soliplex_client_contract_test.dart` | Client package API |
| Client | `test/schema/ask_history_contract_test.dart` | ask_history schema |
| Client | `test/schema/haiku_rag_chat_contract_test.dart` | haiku_rag_chat schema |
| Native | `test/api_contract/soliplex_client_native_contract_test.dart` | Native platform API |

## Test Utilities

Standard `test` and `flutter_test` packages. No custom utilities required.

## Frontend Contract (`soliplex_frontend_contract_test.dart`)

### Features

| Test Case | Verifies |
|-----------|----------|
| default constructor with all parameters | enableHttpInspector, enableQuizzes, etc. |
| minimal constructor | Features.minimal() defaults |
| copyWith signature | Clone functionality |
| equality and hashCode | Value semantics |

### RouteConfig

| Test Case | Verifies |
|-----------|----------|
| default constructor with all parameters | showHomeRoute, showRoomsRoute, initialRoute |
| copyWith signature | Clone functionality |
| equality and hashCode | Value semantics |

### ThemeConfig

| Test Case | Verifies |
|-----------|----------|
| default constructor with all parameters | lightColors, darkColors |
| copyWith signature | Clone functionality |
| equality and hashCode | Value semantics |

### SoliplexColors

| Test Case | Verifies |
|-----------|----------|
| constructor with all required parameters | 15 color properties |
| lightSoliplexColors constant | Default light theme |
| darkSoliplexColors constant | Default dark theme |

### SoliplexConfig

| Test Case | Verifies |
|-----------|----------|
| default constructor with all parameters | App name, backend URL, OAuth scheme, etc. |
| copyWith signature | Clone functionality |
| equality and hashCode | Value semantics |
| oauthRedirectScheme nullable | Web vs native handling |

### runSoliplexApp

| Test Case | Verifies |
|-----------|----------|
| function signature | Entry point accepts config |

### Consumer Simulation

| Test Case | Verifies |
|-----------|----------|
| typical white-label app setup | Custom brand, disabled inspection, custom routes |
| minimal configuration | Default SoliplexConfig works |
| custom theme colors | Color override mechanism |

## Client Contract (`soliplex_client_contract_test.dart`)

### Domain Models

| Test Case | Verifies |
|-----------|----------|
| Room | Constructor, quizIds, hasQuizzes, copyWith |
| ThreadInfo | Constructor, hasInitialRun, copyWith |
| RunInfo | Constructor, RunStatus, copyWith |
| CompletionTime | NotCompleted, CompletedAt variants |
| RunStatus | All enum values accessible |
| ChatMessage | Sealed hierarchy, factory methods, copyWith |
| ToolCallInfo / Status | Tool invocation data structure |

### Errors

| Test Case | Verifies |
|-----------|----------|
| Exception hierarchy | Auth, Network, API, NotFound, Cancelled |
| SoliplexException inheritance | Type hierarchy |
| Specific fields | Status codes, timeouts, resources |

### HTTP Layer

| Test Case | Verifies |
|-----------|----------|
| HttpResponse | Status, body, headers, convenience getters |
| SoliplexHttpClient interface | DartHttpClient implementation |
| HttpClientAdapter | Third-party adapter exists |
| ObservableHttpClient | Observability wrapper exists |
| HttpTransport | Logic wrapper around raw client |
| HttpObserver and events | Event hierarchy for logs |

### Utils

| Test Case | Verifies |
|-----------|----------|
| UrlBuilder | Path and query construction |

### API Layer

| Test Case | Verifies |
|-----------|----------|
| SoliplexApi | All public method signatures |

### Consumer Simulation

| Test Case | Verifies |
|-----------|----------|
| typical API client setup | Full stack assembly |
| create domain models | External fixture creation |
| handle exceptions | Switch exhaustiveness |

## ask_history Schema (`ask_history_contract_test.dart`)

### AskHistory

| Test Case | Verifies |
|-----------|----------|
| fields required by extractor | questions list field |
| json parsing | Nested questions and citations |

### QuestionResponseCitations

| Test Case | Verifies |
|-----------|----------|
| required fields | question, response, citations |
| json keys | Required and optional keys |

### Citation (ask_history)

| Test Case | Verifies |
|-----------|----------|
| required constructor parameters | chunkId, content, documentId, documentUri |
| optional fields | documentTitle, index, headings, pageNumbers |
| json keys | snake_case mapping |
| roundtrip serialization | JSON encode/decode |

### Citation Field Parity (Critical)

| Test Case | Verifies |
|-----------|----------|
| identical required/optional fields | ask_history.Citation == haiku_rag_chat.Citation |
| identical JSON | Same JSON structure |

## haiku_rag_chat Schema (`haiku_rag_chat_contract_test.dart`)

### HaikuRagChat

| Test Case | Verifies |
|-----------|----------|
| fields required by CitationExtractor | citations field |
| json parsing | citation_registry quirk |

### Citation

| Test Case | Verifies |
|-----------|----------|
| fields required by CitationsSection | documentTitle, documentUri, content |
| required/optional parameters | Constructor contracts |
| json keys | snake_case mapping |
| roundtrip serialization | JSON encode/decode |

### QaResponse

| Test Case | Verifies |
|-----------|----------|
| fields | answer, question, citations, confidence |
| json keys | Parsing logic |

### SessionContext

| Test Case | Verifies |
|-----------|----------|
| fields | lastUpdated, summary |
| json keys | Parsing logic |

## Native Platform Contract (`soliplex_client_native_contract_test.dart`)

### createPlatformClient

| Test Case | Verifies |
|-----------|----------|
| function exists | Returns SoliplexHttpClient |
| defaultTimeout parameter | Timeout argument accepted |
| interface | request/stream/close methods |

### Consumer Simulation

| Test Case | Verifies |
|-----------|----------|
| typical setup | Platform client + observability + transport |
| setup with HttpClientAdapter | Third-party library compatibility |
| multiple clients | Independent instances |

## Contract Testing Strategy

### Purpose

Contract tests serve as **breaking change detection**:

1. **Public API Stability**: If a test fails, a consumer-visible API has changed
2. **Schema Compatibility**: Backend/frontend type parity is enforced
3. **Semver Enforcement**: Breaking changes require major version bumps

### Field Parity Tests

The `ask_history` and `haiku_rag_chat` Citation parity test is critical:

```dart
// If this test fails, manual mapping code in CitationExtractor may break
test('identical required/optional fields', () {
  // Verifies both Citation types have same field names and types
});
```

### Consumer Simulation Tests

Simulate how external projects would use the API:

```dart
test('typical white-label app setup', () {
  // External project configuring custom brand
  final config = SoliplexConfig(
    appName: 'MyBrand',
    features: Features(enableHttpInspector: false),
  );
  runSoliplexApp(config: config);
});
```

These tests catch issues like:
- Removed constructors
- Changed parameter names
- Modified return types
- Broken default values

## Test Helpers

| File | Purpose |
|------|---------|
| `test/helpers/test_helpers.dart` | Shared mocks, fixtures, pumpWithProviders |

The test helpers file provides:
- `MockSoliplexApi` - API mock for widget tests
- `TestData` - Factory for test fixtures (rooms, threads, messages)
- `pumpWithProviders()` - Wraps widgets with required providers
- `createTestApp()` - Standard widget test wrapper
- `waitForAuthRestore()` - Async auth session helper
