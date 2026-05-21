# Changelog

## v0.3-alpha - 2026-05-22

### Highlights
- Rebuilt the macOS/Desktop flow as a real app-window experience instead of a browser-opening launcher.
- Added a reproducible macOS `.app` and `.dmg` packaging pipeline.
- Added single-instance protection so repeated launches do not create duplicate local server processes.
- Moved macOS runtime data/settings/history outside the app bundle so reinstalling the app does not wipe local state.
- Hardened macOS packaging checks to keep local paths, build metadata, caches, logs, runtime data, and private files out of release artifacts.

### macOS/Desktop
- Added a `pywebview`/WebKit wrapper that shows SoloDrop inside the app window.
- Removed the external-browser launch path from the normal desktop flow.
- Added startup/status/error screens for server startup failures and port conflicts.
- Added graceful quit/relaunch handling for the embedded backend.
- Added persistent WebView storage under the app runtime directory.

### Packaging
- Added `pc_server/build_macos_dmg.sh` as the canonical macOS packaging entrypoint.
- Added `pc_server/requirements-macos.txt` for macOS desktop wrapper dependencies.
- Added ad-hoc app signing and DMG verification to the macOS build.
- Sanitized build output and removed package `RECORD` metadata that can contain local build paths.
- Ignored generated `.app` and `.dmg` artifacts in git.

### Server
- Added `SOLODROP_RUNTIME_DIR` support so packaged apps can keep config, uploads, previews, logs, and SQLite data outside the bundle.
- Removed local certificate/key paths from HTTPS startup error text.

### Verification
- macOS `.app` build passed.
- macOS `.dmg` build and `hdiutil verify` passed.
- `codesign --verify --deep --strict` passed for the generated app.
- Fresh app launch started exactly one local backend server.
- Repeated app launch did not create duplicate backend listeners.
- Quit/relaunch removed and restored the local listener correctly.
- DMG mount flow showed `SoloDrop.app` plus the Applications shortcut.
- Packaging scan found no runtime databases, logs, `.venv`, `node_modules`, local config, or local project paths inside the final macOS artifacts.

### Known Gaps
- Windows installer asset is not included in this release.
- Developer ID signing and notarization are not configured yet; the macOS app is ad-hoc signed for manual alpha testing.

## v0.2-alpha - 2026-05-20

### Highlights
- Fixed iOS foreground reconnect after app switcher/background transitions.
- Fixed pull-to-refresh recovery so a reachable server can move the UI out of stale offline state.
- Fixed duplicate fresh messages caused by uppercase/lowercase UUID identity drift.
- Improved web message text selection and copy behavior.
- Improved Bonjour-first pairing, manual fallback visibility, and offline-first sync stability.

### iOS
- Added foreground recovery states for REST reachability and WebSocket lifecycle.
- Added stale WebSocket generation checks and cleanup to prevent old callbacks from overwriting newer state.
- Added pull-to-refresh recovery with visible sync result feedback.
- Added keyboard dismissal during scroll and pull-to-refresh without clearing drafts.
- Canonicalized message identity across local sends, WebSocket events, and incremental sync pulls.

### Web UI
- Message text can now be selected and copied without fighting drag/context-menu handlers.
- Pairing and discovery diagnostics are easier to inspect from Settings.

### Server
- Bonjour advertising now exposes a stable `solodrop.local` host while keeping LAN/manual fallback data available.
- Pairing status and trusted device checks normalize device UUIDs consistently.

### Verification
- iOS Simulator build passed.
- Physical iPhone build/install/launch passed.
- Web JavaScript syntax check passed.
- Python server syntax check passed.
- Git whitespace check passed.
