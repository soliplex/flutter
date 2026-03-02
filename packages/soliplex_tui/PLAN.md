# Remove soliplex_client dependency from soliplex_tui (Revised)

## Context

`soliplex_tui` directly depends on `soliplex_client`. The architectural rule is: **consumers depend on `soliplex_agent` only** — it is the public API facade. `soliplex_client` is an implementation detail.

### Problem with the original plan

A blanket `export 'package:soliplex_client/soliplex_client.dart'` leaks HTTP internals (`DartHttpClient`, `HttpTransport`, `UrlBuilder`, `HttpClientAdapter`, auth clients, etc.) through the agent facade. This contradicts the goal of hiding `soliplex_client` as an implementation detail.

Additionally, both `soliplex_tui` (`_buildStack`) and `soliplex_cli` (`createClients`) contain duplicated HTTP wiring logic. Encapsulating this in `soliplex_agent` eliminates duplication and gives the facade something meaningful to own.

### Revised approach

1. Create a `ClientBundle` factory in `soliplex_agent` that encapsulates HTTP wiring
2. Re-export `soliplex_client` with `hide` for HTTP/auth/util internals
3. Replace TUI's `_buildStack` with the new factory
4. Swap imports and remove the direct dependency

`soliplex_cli` has the same pattern but is **out of scope** for this change (it can adopt the factory later).

---

## Step 1: Create `ClientBundle` factory in `soliplex_agent`

**New file:** `packages/soliplex_agent/lib/src/client_bundle.dart`

```dart
import 'package:soliplex_client/soliplex_client.dart';

/// Pre-wired API + AG-UI client bundle.
///
/// Returned by [createClientBundle]. Call [close] when done.
typedef ClientBundle = ({
  SoliplexApi api,
  AgUiClient agUiClient,
  Future<void> Function() close,
});

/// Creates a [ClientBundle] from a server URL.
///
/// Wires up HTTP transport, URL builder, and AG-UI client so that
/// consumers only need a server URL — no knowledge of HTTP internals.
ClientBundle createClientBundle(String serverUrl) {
  final baseUrl = '$serverUrl/api/v1';

  final apiHttpClient = DartHttpClient();
  final sseHttpClient = DartHttpClient();

  final transport = HttpTransport(client: apiHttpClient);
  final urlBuilder = UrlBuilder(baseUrl);

  final api = SoliplexApi(transport: transport, urlBuilder: urlBuilder);
  final agUiClient = AgUiClient(
    config: AgUiClientConfig(baseUrl: baseUrl),
    httpClient: HttpClientAdapter(client: sseHttpClient),
  );

  return (
    api: api,
    agUiClient: agUiClient,
    close: () async {
      await agUiClient.close();
      api.close();
      apiHttpClient.close();
      sseHttpClient.close();
    },
  );
}
```

**Design notes:**
- Uses **separate** `DartHttpClient` instances for REST and SSE (matches `soliplex_cli`'s correct pattern; TUI currently reuses one — a latent bug).
- Async `close` to match TUI's existing await pattern.

**Export from barrel:** `packages/soliplex_agent/lib/soliplex_agent.dart`

```dart
export 'src/client_bundle.dart';
```

---

## Step 2: Re-export soliplex_client with `hide` for internals

**File:** `packages/soliplex_agent/lib/soliplex_agent.dart`

```dart
// Re-export client types so consumers only depend on soliplex_agent.
// Hide HTTP/auth/util internals — consumers use createClientBundle() instead.
export 'package:soliplex_client/soliplex_client.dart'
    hide
        // HTTP internals (use createClientBundle instead)
        AuthenticatedHttpClient,
        DartHttpClient,
        HttpClientAdapter,
        HttpObserver,
        HttpResponse,
        HttpTransport,
        ObservableHttpClient,
        RefreshingHttpClient,
        SoliplexHttpClient,
        TokenRefresher,
        // Auth internals
        OidcDiscovery,
        TokenRefreshService,
        // Util internals (CancelToken already hidden by soliplex_client barrel)
        UrlBuilder;
```

**What remains visible through `soliplex_agent`:**
- Domain models: `ChatMessage`, `Conversation`, `Room`, `ThreadHistory`, `ToolCallInfo`, etc.
- API clients: `SoliplexApi`, `AgUiClient`, `AgUiClientConfig` (needed in constructor signatures and test fakes)
- Tool types: `ToolRegistry`, `ClientTool`, `Tool`
- Streaming: `StreamingState`, `TextStreaming`, `AwaitingText`
- AG-UI protocol: all event types from `ag_ui` (`BaseEvent`, `RunStartedEvent`, etc.)
- AG-UI input: `SimpleRunAgentInput`, `CancelToken` (from `ag_ui`, not the hidden utils one)

**Symbol conflicts:** None.
- `ToolRegistry` — same symbol (soliplex_agent imports it from soliplex_client).
- `CancelToken` — soliplex_client barrel already hides its internal one; the `ag_ui` one passes through.

---

## Step 3: Replace `_buildStack` in `app.dart` with `createClientBundle`

**File:** `packages/soliplex_tui/lib/src/app.dart`

**Remove** the `_Stack` typedef (lines 16–20) and `_buildStack` function (lines 23–43).

**Replace** all call sites (`launchTui`, `runHeadless`, `listRooms`) to use:

```dart
final stack = createClientBundle(serverUrl);
```

The return type is identical in shape (`api`, `agUiClient`, `close`), so all downstream usage (`stack.api`, `stack.agUiClient`, `stack.close()`) works unchanged.

---

## Step 4: Update soliplex_tui imports

Replace `import 'package:soliplex_client/soliplex_client.dart'` → `import 'package:soliplex_agent/soliplex_agent.dart'` in all files. Where a file already imports `soliplex_agent`, just remove the `soliplex_client` line.

**Lib files (6):**
| File | Action |
|------|--------|
| `lib/src/app.dart:7` | Has both imports → remove soliplex_client line |
| `lib/src/components/message_item.dart:2` | Replace with soliplex_agent |
| `lib/src/components/chat_body.dart:3` | Replace with soliplex_agent |
| `lib/src/components/tool_status_bar.dart:2` | Replace with soliplex_agent |
| `lib/src/state/tui_chat_state.dart:1` | Replace with soliplex_agent |
| `lib/src/state/tui_chat_cubit.dart:5` | Has both imports → remove soliplex_client line |

**Test files (5):**
| File | Action |
|------|--------|
| `test/src/headless_test.dart:2` | Replace with soliplex_agent |
| `test/state/tui_chat_cubit_test.dart:6` | Has both imports → remove soliplex_client line |
| `test/state/tui_chat_state_test.dart:1` | Replace with soliplex_agent |
| `test/helpers/test_helpers.dart:5` | Has both imports → remove soliplex_client line |
| `test/helpers/fake_event_stream.dart:3` | Replace with soliplex_agent |

**Test file note:** All 5 test files use only the public barrel (`package:soliplex_client/soliplex_client.dart`) — no deep `src/` imports. `fake_event_stream.dart` uses `CancelToken` and `AgUiClientConfig` which remain visible through the re-export. Verified.

---

## Step 5: Remove soliplex_client from pubspec.yaml

**File:** `packages/soliplex_tui/pubspec.yaml`

Remove:

```yaml
  soliplex_client:
    path: ../soliplex_client
```

`soliplex_client` remains available transitively through `soliplex_agent`.

---

## Verification

```bash
# soliplex_agent must still be clean after changes:
cd packages/soliplex_agent
dart pub get
dart format --set-exit-if-changed .
dart analyze --fatal-infos
dart test

# soliplex_tui must work with only soliplex_agent:
cd packages/soliplex_tui
dart pub get
dart format --set-exit-if-changed .
dart analyze --fatal-infos
dart test

# Confirm no soliplex_client imports remain in TUI:
grep -r 'soliplex_client' packages/soliplex_tui/lib/ packages/soliplex_tui/test/

# Confirm HTTP internals are NOT accessible through soliplex_agent:
# (any import of DartHttpClient etc. in TUI should fail to compile)

# Manual smoke test (backend running on :8000):
cd packages/soliplex_tui
dart run bin/soliplex_tui.dart -s http://localhost:8000 -r echo
```

---

## Future work (out of scope)

- **soliplex_cli:** Adopt `createClientBundle` in `client_factory.dart`, then remove its `soliplex_client` dependency too.
- **soliplex_client_native:** If platform-specific HTTP clients are needed, `createClientBundle` can be extended to accept an optional `SoliplexHttpClient` parameter.
