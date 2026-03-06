# Changelog

## 0.2.0

- Unified `ClientBundle` into `ServerConnection` (#57).
- Replaced `AgUiClient` with `AgUiStreamClient` (#62).
- Routed `AgUiStreamClient` through `HttpTransport` (#63).
- Fixed graceful SSE stream close after terminal events (#64).
- Added `MontyPlugin` interface and `PluginRegistry` wiring (#76).

## 0.1.0

- Initial release.
