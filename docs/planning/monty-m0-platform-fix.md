# M0: Platform Fix (Prerequisite)

**Roadmap:** [monty-integration-roadmap.md](monty-integration-roadmap.md)
**Blocks:** M1, M2, M3, M4

---

## Problem

`thread_bridge_cache.dart` line 3 imports `dart_monty_native` directly:

```dart
import 'package:dart_monty_native/dart_monty_native.dart';
```

This pulls in `dart:isolate` + `dart:ffi` which **breaks web/WASM compilation**.
The web compiler must resolve all imports — tree-shaking happens after.

## Fix

Use the conditional import pattern already in the codebase (`auth_flow.dart`,
`console_sink.dart`, `create_platform_client.dart`):

```text
lib/core/services/
  monty_platform_factory.dart        ← conditional export
  monty_platform_factory_native.dart ← MontyNative + NativeIsolateBindingsImpl
  monty_platform_factory_web.dart    ← MontyWasm + WasmBindingsJs + execution mutex
```

```dart
// monty_platform_factory.dart
import 'monty_platform_factory_native.dart'
    if (dart.library.js_interop) 'monty_platform_factory_web.dart'
    as impl;

MontyPlatform createMontyPlatform() => impl.createMontyPlatform();
```

## Web Concurrency Constraint

On native: one Isolate per thread → true parallel Python execution.
On web: all `MontyWasm` instances share `window.DartMontyBridge` singleton.
Dart on web is single-threaded, but interleaved async calls can corrupt state.

Fix: web factory returns platforms through a mutex/queue that serializes
execution across threads. `DefaultMontyBridge._isExecuting` already guards
single-bridge concurrency; the web mutex guards cross-bridge concurrency.

## Platform Capabilities

dart_monty uses a capability model — callers check with `is` before invoking:

- `MontyNative` implements `MontySnapshotCapable` + `MontyFutureCapable`
- `MontyWasm` implements `MontySnapshotCapable` only (not `MontyFutureCapable`)

Python `async def` / `await` is only available on native. On web, the
capability check (`platform is MontyFutureCapable`) prevents those code paths.

This does NOT affect the roadmap: the `DefaultMontyBridge` start/resume loop
uses the synchronous external function pattern (`MontyPending`), not async
futures. The `MontyResolveFutures` case already has `TODO(M13)` and is a no-op.

Dart `HostFunction` handlers CAN do async work on both platforms — Python
pauses at the external function call, Dart awaits whatever it needs, then
calls `resume()`.

Both platforms implement `MontySnapshotCapable` — snapshot/restore works
everywhere. This could be used to prime interpreters with pre-evaluated state.

## New Files

| File | What |
|------|------|
| `lib/core/services/monty_platform_factory.dart` | Conditional export |
| `lib/core/services/monty_platform_factory_native.dart` | `MontyNative(bindings: NativeIsolateBindingsImpl())` |
| `lib/core/services/monty_platform_factory_web.dart` | `MontyWasm(bindings: WasmBindingsJs())` + mutex |

## Modified

| File | Change |
|------|--------|
| `lib/core/services/thread_bridge_cache.dart` | Remove `dart_monty_native` import. Use `createMontyPlatform()`. |

## Done When

- App compiles on **both native and web**
- Existing `execute_python` tool still works on native
- No `dart:ffi` or `dart:isolate` in the import graph when building for web
