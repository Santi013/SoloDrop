# Changelog

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

