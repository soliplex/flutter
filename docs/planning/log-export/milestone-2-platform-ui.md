# Milestone 2: Platform File Saver + UI Button

**Branch**: `feat/log-export-ui`
**PR title**: `feat(log-viewer): add export button with platform file saver`
**Depends on**: Milestone 1 merged

## Goal

Ship the user-facing feature: download button in the log viewer AppBar,
platform-conditional file saver (class + factory + Riverpod provider),
`share_plus` dependency, and widget tests.

## Changes

### 1. Add `share_plus` dependency

**File**: `pubspec.yaml`

```yaml
share_plus: ^10.1.4  # verify latest compatible with flutter >=3.35.0
```

Run `flutter pub get`.

### 2. Create `LogFileSaver` (class + factory + provider)

Follow the `auth_storage.dart` pattern: abstract class + conditional import
factory + Riverpod provider for test overrides.

**`lib/features/log_viewer/log_file_saver.dart`** — facade:

```dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/features/log_viewer/log_file_saver_native.dart'
    if (dart.library.js_interop)
        'package:soliplex_frontend/features/log_viewer/log_file_saver_web.dart'
    as impl;

abstract class LogFileSaver {
  Future<void> save({
    required String filename,
    required Uint8List bytes,
    Rect? shareOrigin,
  });
}

LogFileSaver createLogFileSaver() => impl.createLogFileSaver();

final logFileSaverProvider = Provider<LogFileSaver>(
  (ref) => createLogFileSaver(),
);
```

**`lib/features/log_viewer/log_file_saver_native.dart`** — gzip + share sheet:

```dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'log_file_saver.dart';

class NativeLogFileSaver implements LogFileSaver {
  @override
  Future<void> save({
    required String filename,
    required Uint8List bytes,
    Rect? shareOrigin,
  }) async {
    final compressed = gzip.encode(bytes);
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$filename.gz';
    await File(path).writeAsBytes(compressed);

    await Share.shareXFiles(
      [XFile(path)],
      sharePositionOrigin: shareOrigin,  // Required for iPad/macOS
    );
  }
}

LogFileSaver createLogFileSaver() => NativeLogFileSaver();
```

> **Note**: Verify `Share.shareXFiles` vs `SharePlus.instance.share(ShareParams(...))`
> against the installed `share_plus` version. Update to match actual API.

**`lib/features/log_viewer/log_file_saver_web.dart`** — browser download:

```dart
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui';

import 'package:web/web.dart' as web;

import 'log_file_saver.dart';

class WebLogFileSaver implements LogFileSaver {
  @override
  Future<void> save({
    required String filename,
    required Uint8List bytes,
    Rect? shareOrigin,  // Accepted but ignored on web
  }) async {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/x-ndjson'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = filename;
    web.document.body!.appendChild(anchor);
    anchor.click();
    web.document.body!.removeChild(anchor);
    web.URL.revokeObjectURL(url);
  }
}

LogFileSaver createLogFileSaver() => WebLogFileSaver();
```

### 3. Add download button to log viewer screen

**File**: `lib/features/log_viewer/log_viewer_screen.dart`

Add `Icons.download` IconButton wrapped in `Builder` (for `RenderBox` access)
before the existing clear button:

```dart
actions: [
  Builder(
    builder: (context) => IconButton(
      icon: const Icon(Icons.download),
      onPressed: records.isEmpty ? null : () => _exportLogs(context),
      tooltip: 'Export filtered logs',
    ),
  ),
  IconButton(
    icon: const Icon(Icons.delete_outline),
    onPressed: records.isEmpty ? null : _controller.clearLogs,
    tooltip: 'Clear all logs',
  ),
],
```

`_exportLogs(BuildContext context)` method:

```dart
Future<void> _exportLogs(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);

  // Compute share origin for iPad/macOS popover positioning.
  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null
      ? box.localToGlobal(Offset.zero) & box.size
      : null;

  // Build filename with filesystem-safe timestamp.
  final now = DateTime.now();
  final ts = '${now.year}-${_pad(now.month)}-${_pad(now.day)}'
      '_${_pad(now.hour)}-${_pad(now.minute)}-${_pad(now.second)}';
  final filename = 'soliplex_logs_$ts.jsonl';

  try {
    final bytes = _controller.exportFilteredAsJsonlBytes();
    final saver = ref.read(logFileSaverProvider);
    await saver.save(
      filename: filename,
      bytes: bytes,
      shareOrigin: origin,
    );
  } catch (e) {
    if (!mounted) return;  // Async gap guard (finding #9)
    messenger.showSnackBar(
      SnackBar(content: Text('Export failed: $e')),
    );
  }
}

static String _pad(int n) => n.toString().padLeft(2, '0');
```

Key details:

- `Builder` wrapper gives the `IconButton`'s own `BuildContext` for `RenderBox`
- Filesystem-safe timestamp: `YYYY-MM-DD_HH-mm-ss` (no colons — finding #8)
- `mounted` check after `await` (finding #9)
- Gets saver from `logFileSaverProvider` (finding #6)
- `shareOrigin` passed through for iPad/macOS (finding #1)

## Files

| File | Action |
|------|--------|
| `pubspec.yaml` | Edit — add `share_plus` |
| `lib/features/log_viewer/log_file_saver.dart` | **New** — abstract class + facade + provider |
| `lib/features/log_viewer/log_file_saver_native.dart` | **New** — gzip + share sheet |
| `lib/features/log_viewer/log_file_saver_web.dart` | **New** — Blob + anchor download |
| `lib/features/log_viewer/log_viewer_screen.dart` | Edit — add download button + handler |
| `test/features/log_viewer/log_viewer_screen_test.dart` | Edit — add button widget tests |

## Tests

### `test/features/log_viewer/log_viewer_screen_test.dart` (additions)

| Test | What it verifies |
|------|------------------|
| `download button is disabled when empty` | `onPressed` is null with no records |
| `download button is enabled with records` | `onPressed` is not null with records |
| `download button shows correct icon` | `Icons.download` present |
| `download button has correct tooltip` | `'Export filtered logs'` |
| `download button appears before clear button` | Icon order in actions |

Widget tests override `logFileSaverProvider` with a no-op fake to avoid
platform calls:

```dart
class FakeLogFileSaver implements LogFileSaver {
  int callCount = 0;
  @override
  Future<void> save({
    required String filename,
    required Uint8List bytes,
    Rect? shareOrigin,
  }) async {
    callCount++;
  }
}
```

## Gates

1. `dart format .` — no changes
2. `flutter analyze --fatal-infos` — 0 issues
3. `flutter pub get` — resolves cleanly (share_plus compatible)
4. `flutter test test/features/log_viewer/log_viewer_screen_test.dart` — passes
5. `flutter test` — full suite passes (no regressions from new provider)
6. Manual: Chrome — browser downloads `.jsonl` with filtered content
7. Manual: macOS — share sheet opens with `.jsonl.gz`, anchored to button
