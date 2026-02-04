# Milestone 07: Feedback Submission

**Status:** pending
**Depends on:** 04-log-viewer-ui, 06-advanced-io-persistence

## Objective

Create a feedback screen that compresses logs and uploads them to the backend
using the existing HTTP transport layer. No new HTTP clients.

**Important:** This milestone depends on BOTH M04 (MemorySink for web) and M06
(FileSink for native compression).

## Pre-flight Checklist

- [ ] M04 complete (MemorySink available for web log source)
- [ ] M06 complete (FileSink with compression available for native)
- [ ] Review `SoliplexApi` and `HttpTransport` for request pattern
- [ ] Review `UrlBuilder` usage in existing services
- [ ] Verify `HttpTransport` supports JSON payloads

## Privacy Considerations

**PII/Redaction Warning:** Logs may contain sensitive information.

- [ ] Document what data may be in logs (URLs, user IDs, error messages)
- [ ] Consider adding redaction for known PII patterns before upload
- [ ] Default "Attach logs" to **false** or show confirmation dialog
- [ ] Add privacy notice in feedback UI explaining what will be sent
- [ ] Log upload is opt-in, never automatic

## Files to Create

- [ ] `packages/soliplex_client/lib/src/api/log_submission_service.dart`
- [ ] `lib/features/feedback/feedback_screen.dart`
- [ ] `test/features/feedback/feedback_screen_test.dart`
- [ ] `packages/soliplex_client/test/api/log_submission_service_test.dart`

## Files to Modify

- [ ] `packages/soliplex_client/lib/soliplex_client.dart` - Export service
- [ ] `lib/core/providers/api_provider.dart` - Add logSubmissionProvider
- [ ] `lib/core/router/app_router.dart` - Add feedback route
- [ ] `lib/features/settings/settings_screen.dart` - Add feedback link

## Implementation Steps

### Step 1: Create LogSubmissionService

**File:** `packages/soliplex_client/lib/src/api/log_submission_service.dart`

- [ ] Accept HttpTransport and UrlBuilder in constructor
- [ ] Implement `submitFeedback({String? message, Uint8List? compressedLogs, Map<String, String>? metadata})`
- [ ] POST to `/feedback` endpoint
- [ ] Set header: `Content-Type: application/json`
- [ ] Send JSON body with base64-encoded logs (avoids header size limits)
- [ ] Return submission ID from response
- [ ] Throw ApiException on failure

**Request format:**

```json
{
  "feedback": "User's feedback message",
  "metadata": {
    "app_version": "1.0.0",
    "platform": "ios",
    "os_version": "17.0"
  },
  "logs": "<base64 encoded gzip data>",
  "logs_encoding": "gzip+base64"
}
```

**Response format:**

```json
{
  "submission_id": "uuid-string",
  "status": "received"
}
```

**Implementation:**

```dart
class LogSubmissionService {
  final HttpTransport _transport;
  final UrlBuilder _urlBuilder;

  LogSubmissionService(this._transport, this._urlBuilder);

  Future<String> submitFeedback({
    String? message,
    Uint8List? compressedLogs,
    Map<String, String>? metadata,
  }) async {
    final body = <String, dynamic>{
      if (message != null) 'feedback': message,
      if (metadata != null) 'metadata': metadata,
      if (compressedLogs != null) ...{
        'logs': base64Encode(compressedLogs),
        'logs_encoding': 'gzip+base64',
      },
    };

    final response = await _transport.post(
      _urlBuilder.build('/feedback'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException('Failed to submit feedback: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['submission_id'] as String;
  }
}
```

### Step 2: Add provider

**File:** `lib/core/providers/api_provider.dart`

- [ ] Create `logSubmissionProvider` Provider
- [ ] Inject httpTransportProvider and urlBuilderProvider
- [ ] Return LogSubmissionService instance

### Step 3: Create FeedbackScreen

**File:** `lib/features/feedback/feedback_screen.dart`

- [ ] TextField for feedback message (multiline)
- [ ] SwitchListTile for "Attach logs" (default **false** for privacy)
- [ ] Privacy notice text explaining what logs contain
- [ ] Submit button with loading state
- [ ] On submit:
  - If attach logs enabled:
    - Native: Get compressed logs from FileSink via `getCompressedLogs()`
    - Web: Format MemorySink records and compress in-memory
  - Call LogSubmissionService.submitFeedback
  - Show success snackbar with submission ID
  - Pop screen on success
- [ ] Handle and display errors

**Web compression helper:**

```dart
Future<Uint8List> compressMemoryLogs(MemorySink sink, LogFormatter formatter) async {
  final buffer = StringBuffer();
  for (final record in sink.records) {
    buffer.writeln(formatter.format(record));
  }
  final bytes = utf8.encode(buffer.toString());
  return Uint8List.fromList(gzip.encode(bytes));
}
```

### Step 4: Update exports

**File:** `packages/soliplex_client/lib/soliplex_client.dart`

- [ ] Export LogSubmissionService

### Step 5: Add routes and settings link

**Files:** `app_router.dart`, `settings_screen.dart`

- [ ] Add `/feedback` route to router
- [ ] Add "Send Feedback" ListTile in settings navigating to feedback screen

### Step 6: Write tests

- [ ] Test LogSubmissionService makes correct POST request with JSON body
- [ ] Test LogSubmissionService includes base64-encoded logs when provided
- [ ] Test LogSubmissionService handles error responses
- [ ] Test FeedbackScreen shows loading state during submit
- [ ] Test FeedbackScreen handles web platform (uses memory logs)
- [ ] Test FeedbackScreen handles native platform (uses file logs)
- [ ] Test privacy toggle defaults to off
- [ ] Test privacy notice is visible
- [ ] Mock HttpTransport for unit tests

## Log Source Strategy

| Platform | Log Source | Compression |
|----------|------------|-------------|
| Native | FileSink files | `getCompressedLogs()` from conditional import |
| Web | MemorySink records | Format + gzip via `dart:convert` |

For web platform, format MemorySink records to text and compress using
`dart:convert` gzip codec (available on web). The `gzip` codec from
`dart:io` is NOT available on web, but `dart:convert` provides `GZipCodec`.

**Note:** On web, use:

```dart
import 'dart:convert' show GZipCodec, utf8;

final codec = GZipCodec();
final compressed = codec.encode(utf8.encode(text));
```

## Validation Gate

Before marking this milestone complete:

### Automated Checks

- [ ] `dart format --set-exit-if-changed .`
- [ ] `flutter analyze --fatal-infos`
- [ ] `flutter test` passes
- [ ] `dart test packages/soliplex_client` passes
- [ ] `flutter build web` succeeds

### Manual Verification

- [ ] Navigate to Settings > Send Feedback
- [ ] Verify privacy toggle defaults to off
- [ ] Verify privacy notice text is visible
- [ ] Submit feedback without logs - verify request succeeds
- [ ] Submit feedback with logs (native) - verify JSON with base64 logs sent
- [ ] Submit feedback with logs (web) - verify JSON with base64 logs sent
- [ ] Verify backend receives and accepts payload (manual check)

### Review Gates

- [ ] **Gemini Review:** Run `mcp__gemini__read_files` with model
  `gemini-3-pro-preview` passing:
  - `docs/planning/logging/07-feedback-submission.md`
  - `packages/soliplex_client/lib/src/api/log_submission_service.dart`
  - `lib/features/feedback/feedback_screen.dart`
  - `lib/core/providers/api_provider.dart`
  - `test/features/feedback/*.dart`
  - `packages/soliplex_client/test/api/log_submission_service_test.dart`
- [ ] **Codex Review:** Run `mcp__codex__codex` to analyze implementation

## Success Criteria

- [ ] Feedback screen accessible from Settings > Send Feedback
- [ ] Privacy toggle defaults to off
- [ ] Privacy notice visible explaining what logs contain
- [ ] Request uses `Content-Type: application/json` with base64 logs
- [ ] Submitting feedback with logs makes POST with correct JSON body
- [ ] Works on web (compresses memory buffer)
- [ ] Works on native (compresses file logs)
- [ ] All tests pass
- [ ] Backend accepts payload (manual verification)
- [ ] Gemini review: PASS
- [ ] Codex review: PASS
