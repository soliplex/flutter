# Logfire UX Improvements

Suggestions for improving how client-side Flutter logs appear in the
Logfire dashboard. These build on the working end-to-end pipeline
(12.1-12.5) and can be adopted incrementally.

## 1. Tags for Filtering (DONE)

Add `tags=["client"]` to every `logfire.log()` call in the ingest
endpoint. This lets you filter client logs vs server-side traces in the
Logfire dashboard using tag-based queries.

**File:** `src/soliplex/views/log_ingest.py`

```python
logfire.log(
    level=entry.level.lower(),
    msg_template="{logger}: {message}",
    attributes=attrs,
    tags=["client"],
)
```

## 2. Resource Attributes on Batch Span

The Flutter payload includes a `resource` dict with device and app
metadata (`app.version`, `os.type`, `device.model`). Attach these to the
`client_log_batch` span so you see device context at the batch level
without it repeating on every individual entry.

```python
with logfire.span(
    "client_log_batch",
    install_id=first.installId if first else "",
    session_id=first.sessionId if first else "",
    count=len(payload.logs),
    **payload.resource,  # app.version, os.type, device.model
):
```

## 3. Suppress Console Echo

Set `console_log=False` on the `logfire.log()` calls to prevent client
logs from also appearing in the server's stdout. Client logs are already
in Logfire; echoing them to the server console adds noise.

```python
logfire.log(
    level=entry.level.lower(),
    msg_template="{logger}: {message}",
    attributes=attrs,
    tags=["client"],
    console_log=False,
)
```

## 4. Richer Error Spans

When a log entry has `error` and/or `stackTrace` fields, use a dedicated
`logfire.span()` with error status instead of a flat `logfire.log()`.
This enables Logfire's built-in error highlighting, stack trace rendering,
and error rate dashboards.

```python
if entry.error or entry.stackTrace:
    with logfire.span(
        "{logger}: {message}",
        logger=entry.logger,
        message=entry.message,
        tags=["client", "error"],
        **attrs,
    ) as span:
        if entry.stackTrace:
            span.record_exception(
                Exception(entry.error or entry.message),
            )
        span.set_status("error")
else:
    logfire.log(...)
```

## 5. Simpler Message Template

Logfire already renders severity level with color badges. The current
approach uses string concatenation for `msg_template`.

**Gotcha:** Do NOT use f-strings or `{key}` template syntax in
`msg_template` — Logfire re-interprets curly braces as template variables
and displays them literally. Always use plain string concatenation:

```python
# GOOD — concatenation
msg = entry.logger + ": " + entry.message
logfire.log(level=..., msg_template=msg, ...)

# BAD — Logfire shows {logger}: {message} literally
logfire.log(level=..., msg_template="{logger}: {message}", ...)

# BAD — Logfire shows {entry.logger}: {entry.message} literally
logfire.log(level=..., msg_template=f"{entry.logger}: {entry.message}", ...)
```

Pick based on how you use the Logfire search/filter UI.

## 6. Breadcrumb Sub-Span

When an error entry includes breadcrumbs (the last 20 log records before
the error), create a collapsible child span:

```python
if "breadcrumbs" in entry_attrs:
    breadcrumbs = entry_attrs.pop("breadcrumbs")
    with logfire.span(
        "breadcrumbs",
        count=len(breadcrumbs),
        items=breadcrumbs,
    ):
        pass  # breadcrumbs visible when expanding the span
```

This keeps the breadcrumb data available for debugging without cluttering
the main log view.

## Implementation Priority

| # | Suggestion | Effort | Impact |
|---|-----------|--------|--------|
| 1 | Tags for filtering | Done | High |
| 2 | Resource on batch | Small | Medium |
| 3 | Suppress console | Trivial | Low |
| 4 | Richer errors | Medium | High |
| 5 | Simpler template | Trivial | Low |
| 6 | Breadcrumb span | Medium | Medium |

Suggestions 2 and 3 are quick wins. Suggestion 4 adds the most value for
production debugging.
