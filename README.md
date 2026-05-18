# SoloDrop

SoloDrop is a LAN-first, offline-first app for moving text, links, files, photos, and other media between a Windows PC and an iPhone. It does not use cloud services: data stays on the local network and on the user's devices.

## Architecture

- Windows server: Python, FastAPI, Uvicorn, SQLite, WebSocket, QR setup, mDNS/Bonjour, pairing, device whitelist, local file storage.
- iOS client: SwiftUI, local-first SQLite storage, local file cache, sync queue, retry/backoff, NetworkMonitor, server health checks, Bonjour discovery, pairing flow, WebSocket realtime with pull-sync fallback.
- Sync model: every item has a UUID; push/upload requests are idempotent; duplicate UUIDs are acknowledged without creating duplicate data.
- Security model: pairing is required, devices are whitelisted, production mode supports HTTPS/WSS with local certificates.

## Backend API

- `GET /health`
- `POST /upload`
- `GET /files/{filename}`
- `POST /sync/push`
- `GET /sync/pull`
- `GET /pair/code`
- `POST /pair/verify`
- `GET /pair/qr`
- `WS /ws`

## Run Server In Dev Mode

```bat
cd pc_server
py -3 -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\python.exe run_server.py
```

Or:

```bat
cd pc_server
start_server.bat
```

`start_server.bat` bootstraps a local `.venv` and installs `requirements.txt` when dependencies are missing. Installed builds run `SoloDropServer.exe` directly.

Dev mode runs over HTTP by default. Production mode should set `https_enabled` to `true` in a local `pc_server/config.json` and provide `pc_server/certs/cert.pem` plus `pc_server/certs/key.pem`.

## Configuration

Commit only `pc_server/config.example.json`. On first backend import/start, SoloDrop creates a local ignored `pc_server/config.json` from that example when it is missing. You can also create it manually and edit it:

```bat
copy pc_server\config.example.json pc_server\config.json
```

`config.json` is ignored because it may contain local ports, paths, HTTPS settings, and private certificate paths.

## Build `server.exe`

```bat
cd pc_server
build_exe.bat
```

The build creates `pc_server/dist/SoloDropServer/SoloDropServer.exe`. Do not commit `dist/` or `.exe` files; attach them to a GitHub Release instead.

## Build Windows Installer

Install Inno Setup 6, then run:

```bat
cd pc_server
build_installer.bat
```

The installer output is `pc_server/installer/SoloDropSetup.exe`. Do not commit installer binaries to the main repository.

## Connect iPhone

1. Start the Windows server.
2. Open `http://<PC-IP>:8000/pair/code` on the PC to get a PIN.
3. Open the iOS app settings.
4. Choose a discovered Bonjour server or enter `http://<PC-IP>:8000`.
5. Enter the PIN and pair the device.
6. The iPhone stores the server config locally and syncs pending items when the server is reachable.

The QR endpoint `GET /pair/qr` contains the server URL, pairing endpoints, IP/port, and manual fallback data.

## Offline-First Behavior

- The iOS UI reads from local SQLite first and does not require the Windows server to be online.
- New text/link/file/media items are saved locally immediately with `pending` status.
- Files are cached locally under the app Documents `SoloDrop/uploads` folder.
- The sync queue pushes pending items later through `/sync/push` or `/upload`.
- Failed syncs remain visible as `failed` and can be retried.
- When the server returns, `SyncManager` health-checks `/health`, pushes pending items, pulls remote changes, and reconnects WebSocket.
- If WebSocket is unavailable, pull sync still works.

## What Is Not Committed

- Virtual environments and Python caches.
- PyInstaller `build/`, `dist/`, `.spec`, `.exe`.
- Inno Setup output and installer `.exe`.
- Runtime `data/`, `uploads/`, local SQLite databases, logs, previews.
- Private certificates and keys.
- Local `config.json`, `.env`, pairing/session/device whitelist data.
- User files, transferred media, generated QR images, and temp files.

## Troubleshooting

### Windows Firewall

Allow SoloDrop/Python through Windows Firewall on Private networks. The server listens on `0.0.0.0:8000` by default.

### iPhone Does Not See Server

Make sure both devices are on the same LAN/Wi-Fi, the server is running, and `http://<PC-IP>:8000/health` returns `online: true`.

### mDNS/Bonjour Does Not Work

Use manual IP entry or QR setup. The server continues running even if Bonjour registration fails.

### HTTPS Certificate Warning

Development mode uses HTTP. Production mode requires a trusted local certificate in `pc_server/certs/cert.pem` and `pc_server/certs/key.pem`, with `https_enabled: true`.

### Pending Items Do Not Sync

Check pairing status, server `/health`, Wi-Fi/LAN connectivity, and Windows Firewall. Failed items stay local and can be retried from the iOS UI.
