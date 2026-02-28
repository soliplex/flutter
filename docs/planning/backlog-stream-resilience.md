# Backlog: Event Stream Resilience Pipeline

**Status**: Deferred — optimize when jank is observed
**Trigger**: Python `print()` in tight loops causes dropped frames in Flutter UI

---

## Problem

`execute_python` bridge emits AG-UI events (StepStarted, ToolCallStart/End/Result, TextMessageContent) back to Flutter UI. If Python emits events faster than 60fps, naive `listen` + state update per event causes jank.

**Current state**: Events processed immediately in `active_run_notifier.dart:739`. No batching/throttling. Works fine for normal usage.

---

## Strategy: Route Different Event Types Through Different Pipelines

No RxDart needed — use native Dart `StreamTransformer.fromHandlers` (already proven in `observable_http_client.dart`).

### Event Classification

| Event Type | Pipeline | Strategy |
|------------|----------|----------|
| `ToolCallResultEvent`, `RunErrorEvent` | Critical | Immediate passthrough — never throttle |
| `ToolCallStartEvent`, `ToolCallEndEvent` | Critical | Immediate passthrough |
| `TextMessageContentEvent` | Batchable | Frame-aligned batching (~16ms) |
| `StepStartedEvent`, `StepFinishedEvent` | Debounceable | Throttle at 250ms (user sees momentum) |
| Large JSON payloads (>1KB) | Heavy | `Isolate.run()` for parsing |

---

## Technique Reference

### 1. Frame-Aligned Batching (Best for text output)

Batches events per Flutter frame using `SchedulerBinding.addPostFrameCallback`. Guarantees max 1 UI rebuild per frame regardless of event frequency.

```dart
class FrameBatcher<T> extends StreamTransformerBase<T, List<T>> {
  @override
  Stream<List<T>> bind(Stream<T> stream) {
    late StreamController<List<T>> controller;
    StreamSubscription<T>? subscription;
    var buffer = <T>[];
    var frameScheduled = false;

    void scheduleFlush() {
      if (frameScheduled) return;
      frameScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (buffer.isNotEmpty) {
          controller.add(buffer);
          buffer = <T>[];
        }
        frameScheduled = false;
      });
    }

    controller = StreamController<List<T>>(
      onListen: () {
        subscription = stream.listen(
          (event) { buffer.add(event); scheduleFlush(); },
          onError: controller.addError,
          onDone: () {
            if (buffer.isNotEmpty) controller.add(buffer);
            controller.close();
          },
        );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }
}
```

- Latency: 0-16ms (one frame)
- Preserves all events
- Tested pattern for Flutter

### 2. Microtask Batching (Best for synchronous bursts)

SSE chunks can contain many events separated by `\n\n`. The parser emits them synchronously. This coalesces them in a single event loop tick.

```dart
StreamTransformer<BaseEvent, List<BaseEvent>>.fromHandlers(
  handleData: (event, sink) {
    if (_buffer.isEmpty) {
      Future.microtask(() {
        sink.add(List.from(_buffer));
        _buffer.clear();
      });
    }
    _buffer.add(event);
  },
)
```

- Latency: near-zero
- Preserves all events

### 3. Throttle (Best for status updates)

Use `throttleTime` NOT `debounceTime` for step progress — user should feel momentum, not wait for silence.

```dart
// Native Dart throttle (no RxDart)
Timer? _throttleTimer;
BaseEvent? _latestStatus;

void onStatusEvent(BaseEvent event) {
  _latestStatus = event;
  _throttleTimer ??= Timer(Duration(milliseconds: 250), () {
    if (_latestStatus != null) processStatus(_latestStatus!);
    _throttleTimer = null;
    _latestStatus = null;
  });
}
```

- Latency: up to 250ms
- Drops intermediate events (only latest matters)

### 4. Isolate Parsing (Best for heavy payloads)

For chart JSON / DataFrame previews >1KB. Use single long-lived isolate for FIFO ordering.

```dart
Future<Map<String, dynamic>> parseHeavyResult(String rawJson) async {
  return await Isolate.run(() => jsonDecode(rawJson) as Map<String, dynamic>);
}
```

**Important**: Do NOT use per-event `Isolate.run()` for streams — breaks ordering. Use a single long-lived isolate with `ReceivePort` to maintain FIFO.

---

## Backpressure: The "Infinite Print" Problem

`while True: print("spam")` will OOM if accumulated indefinitely.

**Solution**: Cap buffer at 50KB per frame batch. Truncate middle:

```text
[first 25KB of output]
...[output truncated — 1.2MB total]...
[last 25KB of output]
```

---

## SSE Reconnection

- Investigate `Last-Event-ID` support in `AgUiClient`
- Cache last processed event ID
- Reconnect with `Last-Event-ID` header for replay
- Requires backend support too

---

## Testing Strategy

- `MockJankStream`: emit 10,000 TextMessageContent events synchronously
- Verify frame batcher produces ≤ N batches for N frames
- Verify backpressure caps at 50KB
- Use existing `FakeAgUiClient` + `buildMockEventStream` helpers
- `flutter drive` + `FrameTiming` API for p99 frame time < 16ms

---

## Gemini Analysis Notes (Feb 2026)

### 2.5 Pro highlights

- Detailed code snippets with error handling
- 50KB backpressure cap suggestion
- `flutter drive` + `FrameTiming` for p99 assertion
- `Last-Event-ID` reconnection strategy

### 3.1 Pro highlights

- SSE chunks emit events synchronously from parser — microtask batching absorbs perfectly
- Single long-lived background isolate with ReceivePort for FIFO guarantee
- `throttleTime` > `debounceTime` for status — user feels momentum

### Both agreed

- Frame-aligned batching is best for text output
- Critical events must never be throttled
- Zone values are fragile — use closure capture
- No RxDart needed — native Dart StreamTransformer sufficient
