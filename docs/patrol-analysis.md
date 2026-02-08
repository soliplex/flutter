# Patrol Integration Testing Analysis

> Collaborative analysis by Claude, Gemini (2.5-pro), and Codex (gpt-5.2)
> Date: 2026-01-20

## Executive Summary

This document analyzes the setup requirements for Patrol integration tests in the
Soliplex Flutter frontend. The goal is a minimal, LLM-compatible test suite that
connects to a live backend in no-auth-mode.

## Current State

### Existing Infrastructure

- `integration_test/tool_calling_test.dart` - Uses mocked AG-UI streams
- `integration_tests/whitelabel_config_test.dart` - Tests against live backend
  (gitignored)
- `integration_test` SDK already in pubspec.yaml
- macOS bundle ID: `ai.soliplex.client`
- Test helpers in `test/helpers/test_helpers.dart`

### API Endpoints (from soliplex_client)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/rooms` | GET | List rooms |
| `/api/v1/rooms/{roomId}/agui` | GET | List threads |
| `/api/v1/rooms/{roomId}/agui` | POST | Create thread |
| `/api/v1/rooms/{roomId}/agui/{threadId}` | POST | Create run (starts SSE) |

## Patrol Setup Requirements

### 1. Dependencies (pubspec.yaml)

```yaml
dev_dependencies:
  patrol: ^4.3.0
  patrol_finders: ^3.0.0  # Optional but recommended for cleaner finders
```

### 2. Patrol Configuration (pubspec.yaml)

```yaml
patrol:
  app_name: Soliplex
  test_directory: integration_test
  macos:
    bundle_id: ai.soliplex.client
  ios:
    bundle_id: ai.soliplex.client
```

### 3. CLI Installation

```bash
dart pub global activate patrol_cli
```

## Test Architecture Recommendations

### File Organization (LLM-Compatible)

```
integration_test/
├── patrol_test_base.dart      # Shared setup, helpers, _NoAuthNotifier
├── live_chat_test.dart        # Room nav + chat send/receive
├── live_tool_calling_test.dart # Client tool execution
└── README.md                  # Test inventory for LLM reference
```

**Naming Convention**: Use dot-separated IDs for test names:

- `live.rooms.load` - Load rooms from backend
- `live.chat.send_receive` - Send message, receive streaming response
- `live.tools.client_execution` - Client-side tool calling

### Streaming Response Pattern

**Critical**: Avoid `pumpAndSettle()` for streaming - it hangs waiting for
streams to close.

Use condition-based polling:

```dart
Future<void> waitForCondition(
  WidgetTester tester, {
  required bool Function() condition,
  required Duration timeout,
  Duration step = const Duration(milliseconds: 200),
  String? failureMessage,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (condition()) return;
  }
  fail(failureMessage ?? 'Timed out after $timeout');
}
```

### Screenshot on Failure

Wrap tests with automatic screenshot capture:

```dart
void patrolTestWithScreenshot(
  String id,
  Future<void> Function(PatrolTester $) body,
) {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  patrolTest(id, ($) async {
    try {
      await body($);
    } catch (_) {
      final safeName = id.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      await binding.takeScreenshot('FAIL__$safeName');
      rethrow;
    }
  });
}
```

### Backend Connectivity

**Preflight Check**: Before running UI tests, verify backend is reachable:

```dart
Future<void> verifyBackendOrFail(String backendUrl) async {
  try {
    final res = await http.get(Uri.parse('$backendUrl/api/v1/rooms'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      fail('Backend returned ${res.statusCode}');
    }
  } catch (e) {
    fail('Backend unreachable at $backendUrl: $e');
  }
}
```

**Environment Variable**: Use `SOLIPLEX_BACKEND_URL` (default: `localhost:8000`)

```dart
const backendUrl = String.fromEnvironment(
  'SOLIPLEX_BACKEND_URL',
  defaultValue: 'http://localhost:8000',
);
```

## Test Isolation Strategy

### For Live Backend Tests

1. **Create fresh threads per test** - Don't reuse existing threads
2. **Use unique message tokens** - Include timestamp in test messages
3. **Cleanup via tearDown** - Delete test threads after completion
4. **Prefix test data** - Use `test-` prefix for easy identification

### Provider Overrides (Existing Pattern)

Continue using `ProviderScope.overrides` as established:

```dart
ProviderScope(
  overrides: [
    shellConfigProvider.overrideWithValue(config),
    authProvider.overrideWith(_NoAuthNotifier.new),
  ],
  child: Consumer(...),
)
```

## macOS-Specific Considerations

### Keyboard Assertion Workaround

Keep the existing workaround for Flutter macOS keyboard bug:

```dart
void ignoreKeyboardAssertions() {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('_pressedKeys.containsKey') ||
        details.exception.toString().contains('KeyUpEvent is dispatched')) {
      return; // Ignore
    }
    originalOnError?.call(details);
  };
}
```

### Entitlements

macOS entitlements already include `com.apple.security.network.client` for
localhost connections.

## CI/CD Considerations

### GitHub Actions Workflow

```yaml
integration-test:
  runs-on: macos-latest
  timeout-minutes: 30
  steps:
    - uses: actions/checkout@v4
    - uses: subosito/flutter-action@v2
      with:
        channel: stable
        cache: true
    - name: Install Patrol CLI
      run: dart pub global activate patrol_cli
    - name: Run integration tests
      env:
        SOLIPLEX_BACKEND_URL: ${{ secrets.STAGING_BACKEND_URL }}
      run: |
        flutter pub get
        patrol test --target integration_test/live_chat_test.dart
    - name: Upload screenshots
      if: failure()
      uses: actions/upload-artifact@v4
      with:
        name: patrol-screenshots
        path: build/patrol/screenshots/
```

### Local Development

```bash
# Start backend in no-auth-mode
cd soliplex && soliplex-cli serve example/minimal.yaml --no-auth-mode

# Run Patrol tests
SOLIPLEX_BACKEND_URL=http://localhost:8000 patrol test
```

## Comparison: Patrol vs integration_test

| Feature | integration_test | Patrol |
|---------|------------------|--------|
| Native UI (OIDC popup) | No | Yes |
| Custom finders | No | Yes (`$('text')`) |
| Screenshot on failure | Manual | Built-in flag |
| Hot restart | No | Yes |
| CLI tooling | flutter test | patrol test |
| Learning curve | Low | Low (extends existing) |

**Recommendation**: Use Patrol for future-proofing (OIDC, location permissions)
while keeping tests simple enough to run with `flutter test` as fallback.

## Test Scenarios (Priority Order)

### 1. live.rooms.load

- GET /api/v1/rooms
- Verify RoomListTile widgets render
- Screenshot room list

### 2. live.chat.send_receive

- Navigate to room
- Send message via chat input
- Wait for streaming response (SSE)
- Verify ChatMessageWidget appears with response

### 3. live.tools.client_execution

- Send message that triggers tool call
- Verify ToolCallStartEvent processed
- Verify client executor runs
- Verify continuation run with tool result

## Appendix: Key Files Reference

| File | Purpose |
|------|---------|
| `lib/core/providers/api_provider.dart` | API client providers |
| `lib/core/providers/active_run_notifier.dart` | AG-UI streaming orchestration |
| `packages/soliplex_client/lib/src/application/tool_registry.dart` | Client tool registration |
| `test/helpers/test_helpers.dart` | Mock factories and test utilities |
