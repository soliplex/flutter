---
name: debugging
description: Debug Flutter UI issues using the widget inspector. Use when a finder fails, a widget isn't rendering as expected, you need to verify text values, or you're investigating runtime errors.
allowed-tools: Bash, Read, Glob, Grep
---

# Flutter Debugging Skill

Debug Flutter UI issues by inspecting and interacting with a live app via
the Dart Tooling Daemon (DTD) and flutter_driver.

- **Inspection** (widget tree, errors, logs) works with any running app.
- **Interaction** (tap, enter text, scroll) requires flutter_driver.

## CRITICAL PROTOCOL

**YOU MUST** run `mcp__dart-tools__get_widget_tree` before writing a
single line of test code or modifying an existing finder.

**DO NOT GUESS** widget text or types based on Dart source code.

1. Source code shows variables (e.g., `room.name`).
2. Widget tree shows reality (e.g., `"Gemini 2.5 Flash"`).
3. If you write a finder without inspecting the tree first, you are
   breaking protocol.

## Relationship to Other Skills

This skill provides the tools for **Phase 1 (Discover)** of the Patrol
E2E testing workflow. You MUST use the tools here (`get_widget_tree`,
`get_app_logs`) to gather the correct finders and log patterns *before*
writing or modifying a Patrol test in Phase 2.

The `logging` skill defines the log message conventions that produce the
`[DEBUG]` patterns you will see in `get_app_logs` and assert against in
`harness.expectLog()`.

## Workflow

### 1. Launch the app

For **inspection only** (widget tree, logs, errors):

```text
mcp__dart-tools__launch_app(root, device: "macos")
```

For **inspection + interaction** (tap, enter text, scroll):

```text
mcp__dart-tools__launch_app(root, device: "macos",
    target: "test_driver/app.dart")
```

The `test_driver/app.dart` entry point calls
`enableFlutterDriverExtension()` which enables flutter_driver commands.
Requires `flutter_driver` as a dev dependency in `pubspec.yaml`.

Returns `dtdUri` and `pid`. The app opens on the target device.

### 2. Connect to the Dart Tooling Daemon

```text
mcp__dart-tools__connect_dart_tooling_daemon(uri: <dtdUri>)
```

One connection per session. If already connected, skip this step.

### 3. Inspect the widget tree

```text
mcp__dart-tools__get_widget_tree(summaryOnly: true)
```

- `summaryOnly: true` returns only user-created widgets (skips framework
  internals).
- **Extract the exact `widgetRuntimeType` string.** Use this directly
  in your `find.byType(WidgetType)` finder.
- **Extract the exact `textPreview` string.** Use this to determine if
  you need an exact match or a substring match with
  `findByTextContaining`. This step prevents exact-match bugs like the
  "Gemini" vs "Gemini 2.5 Flash" failure.

### 4. Check for errors

```text
mcp__dart-tools__get_runtime_errors()
mcp__dart-tools__get_app_logs(pid: <pid>, maxLines: 50)
```

- `get_runtime_errors` shows uncaught exceptions in the running app.
- `get_app_logs` shows stdout output including `[DEBUG]` log lines.
- Copy the specific `[DEBUG]` log pattern (logger name + message) into
  your `harness.expectLog` or `harness.waitForLog` call.

### 5. Interactive widget selection (optional)

```text
mcp__dart-tools__set_widget_selection_mode(enabled: true)
```

Ask the user to tap a widget in the running app, then:

```text
mcp__dart-tools__get_selected_widget()
```

Returns full details of what the user selected. Useful when the tree is
large and you need to locate a specific widget.

### 6. Clean up

```text
mcp__dart-tools__stop_app(pid: <pid>)
```

**ALWAYS check for lingering processes** after stopping:

```bash
ps aux | grep "Soliplex.app" | grep -v grep
```

Kill any orphaned processes. The DTD `stop_app` call does not always
terminate the macOS process cleanly.

Also run `mcp__dart-tools__list_running_apps` before launching to avoid
starting duplicate instances.

## When to Use This Skill

- A `find.byType` or `find.widgetWithText` finder isn't matching
- You need to see what text a widget actually displays
- A widget isn't rendering or is in an unexpected state
- You're writing new finders and want to verify the widget hierarchy
- You're investigating runtime errors or unexpected behavior
- The `patrol` skill directs you here for Phase 1 Discovery

## Anti-Patterns

1. **GUESSING FINDERS**: Never write a finder based on reading Dart
   source code. The rendered UI is the only source of truth.
   Action: Run `get_widget_tree` first.

2. **SKIPPING INSPECTION**: Do not fix a failing test by tweaking the
   finder repeatedly. This is inefficient.
   Action: Stop, launch the app, inspect the tree, find the correct
   value in one step.

3. **LEAVING ORPHAN PROCESSES**: `stop_app` can fail to terminate the
   app. A lingering process will interfere with the next run.
   Action: After `stop_app`, ALWAYS run
   `ps aux | grep "Soliplex.app"` and kill any remaining processes.

4. **MULTIPLE INSTANCES**: Launching the app without checking if one
   is already running creates confusion and port conflicts.
   Action: Run `list_running_apps` before `launch_app`.
