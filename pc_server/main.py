from __future__ import annotations

import asyncio
import io
import json
import logging
import mimetypes
import secrets
import hashlib
import hmac
import os
import shutil
import socket
import sqlite3
import sys
import threading
import uuid
from contextlib import asynccontextmanager
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import qrcode
from fastapi import (
    FastAPI,
    File,
    Form,
    HTTPException,
    Query,
    Request,
    UploadFile,
    WebSocket,
    WebSocketDisconnect,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from starlette.responses import Response

try:
    from PIL import Image
    from pillow_heif import register_heif_opener

    register_heif_opener()
except ImportError:
    Image = None

try:
    from zeroconf import ServiceInfo, Zeroconf
except ImportError:
    ServiceInfo = None
    Zeroconf = None


SOURCE_DIR = Path(__file__).resolve().parent
RESOURCE_DIR = Path(getattr(sys, "_MEIPASS", SOURCE_DIR)) if getattr(sys, "frozen", False) else SOURCE_DIR


def runtime_base_dir() -> Path:
    override = os.environ.get("SOLODROP_RUNTIME_DIR")
    if override:
        return Path(override).expanduser()
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return SOURCE_DIR


BASE_DIR = runtime_base_dir()
BASE_DIR.mkdir(parents=True, exist_ok=True)

CONFIG_PATH = BASE_DIR / "config.json"
CONFIG_EXAMPLE_PATH = BASE_DIR / "config.example.json"
STATIC_DIR = RESOURCE_DIR / "static"
if not STATIC_DIR.exists():
    STATIC_DIR = BASE_DIR / "static"
APP_NAME = "SoloDrop"
APP_VERSION = "0.3.0-alpha"
ADMIN_SESSION_COOKIE = "solodrop_admin_session"
ADMIN_SESSION_HEADER = "x-solodrop-admin-session"
ADMIN_SESSION_TTL_SECONDS = 12 * 60 * 60

logger = logging.getLogger("solodrop")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")

mimetypes.add_type("image/heic", ".heic")
mimetypes.add_type("image/heif", ".heif")


@dataclass(frozen=True)
class ServerConfig:
    host: str = "0.0.0.0"
    port: int = 8000
    public_host: str = "solodrop.local"
    https_enabled: bool = False
    cert_path: str = "certs/cert.pem"
    key_path: str = "certs/key.pem"
    storage_dir: str = "data"
    uploads_dir: str = "data/uploads"
    previews_dir: str = "data/previews"
    logs_dir: str = "logs"
    database_path: str = "data/solodrop.sqlite3"
    mdns_enabled: bool = True
    pairing_enabled: bool = True
    pairing_code_ttl_seconds: int = 300
    service_name: str = "SoloDrop"
    service_type: str = "_http._tcp.local."
    mode: str = "dev"

    @classmethod
    def load(cls) -> "ServerConfig":
        if not CONFIG_PATH.exists():
            if CONFIG_EXAMPLE_PATH.exists():
                shutil.copyfile(CONFIG_EXAMPLE_PATH, CONFIG_PATH)
            else:
                return cls()

        with CONFIG_PATH.open("r", encoding="utf-8") as handle:
            raw = json.load(handle)

        allowed = cls.__dataclass_fields__.keys()
        values = {key: value for key, value in raw.items() if key in allowed}
        return cls(**values)

    def resolve_path(self, value: str) -> Path:
        path = Path(value)
        if path.is_absolute():
            return path
        return BASE_DIR / path

    @property
    def scheme(self) -> str:
        return "https" if self.https_enabled else "http"

    @property
    def websocket_scheme(self) -> str:
        return "wss" if self.https_enabled else "ws"


config = ServerConfig.load()
DATA_DIR = config.resolve_path(config.storage_dir)
UPLOADS_DIR = config.resolve_path(config.uploads_dir)
PREVIEWS_DIR = config.resolve_path(config.previews_dir)
LOGS_DIR = config.resolve_path(config.logs_dir)
DATABASE_PATH = config.resolve_path(config.database_path)

DATA_DIR.mkdir(parents=True, exist_ok=True)
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
PREVIEWS_DIR.mkdir(parents=True, exist_ok=True)
LOGS_DIR.mkdir(parents=True, exist_ok=True)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def parse_iso(value: str | None) -> datetime:
    if not value:
        return datetime.fromtimestamp(0, tz=timezone.utc)
    normalized = value.replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError:
        return datetime.fromtimestamp(0, tz=timezone.utc)
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def ensure_uuid(value: str, field_name: str = "id") -> str:
    try:
        return str(uuid.UUID(value))
    except (TypeError, ValueError) as exc:
        raise HTTPException(status_code=400, detail=f"{field_name} must be a UUID") from exc


def normalize_uuid(value: str | None) -> str | None:
    if not value:
        return None
    try:
        return str(uuid.UUID(str(value)))
    except (TypeError, ValueError):
        return None


def safe_name(value: str | None, fallback: str = "file") -> str:
    candidate = Path(value or fallback).name.strip()
    return candidate or fallback


def get_lan_ip() -> str:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.settimeout(0.2)
            sock.connect(("10.255.255.255", 1))
            return sock.getsockname()[0]
    except OSError:
        try:
            return socket.gethostbyname(socket.gethostname())
        except OSError:
            return "127.0.0.1"


def server_base_url(host: str | None = None) -> str:
    resolved_host = host or config.public_host
    if resolved_host in {"0.0.0.0", "::", ""}:
        resolved_host = get_lan_ip()
    return f"{config.scheme}://{resolved_host}:{config.port}"


def mdns_hostname(host: str) -> str:
    cleaned = host.strip().rstrip(".")
    return f"{cleaned or 'solodrop.local'}."


def database_connection() -> sqlite3.Connection:
    connection = sqlite3.connect(DATABASE_PATH)
    connection.row_factory = sqlite3.Row
    return connection


def initialize_database() -> None:
    with database_connection() as connection:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS items (
                id TEXT PRIMARY KEY,
                item_type TEXT NOT NULL,
                text TEXT,
                file_name TEXT,
                stored_name TEXT,
                file_url TEXT,
                preview_url TEXT,
                mime_type TEXT,
                sender TEXT NOT NULL DEFAULT 'ios',
                device_id TEXT,
                server_id TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                deleted INTEGER NOT NULL DEFAULT 0
            )
            """
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS processed_items (
                id TEXT PRIMARY KEY,
                operation TEXT NOT NULL,
                processed_at TEXT NOT NULL,
                metadata TEXT
            )
            """
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS devices (
                device_id TEXT PRIMARY KEY,
                device_name TEXT,
                token_hash TEXT,
                paired_at TEXT NOT NULL,
                last_seen_at TEXT NOT NULL
            )
            """
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS pairing_codes (
                code TEXT PRIMARY KEY,
                created_at TEXT NOT NULL,
                expires_at TEXT NOT NULL
            )
            """
        )
        connection.execute("CREATE INDEX IF NOT EXISTS idx_items_updated_at ON items(updated_at)")
        connection.execute("CREATE INDEX IF NOT EXISTS idx_items_device_id ON items(device_id)")
        columns = {row["name"] for row in connection.execute("PRAGMA table_info(devices)").fetchall()}
        if "token_hash" not in columns:
            connection.execute("ALTER TABLE devices ADD COLUMN token_hash TEXT")
        migrate_legacy_messages(connection)
        connection.commit()


def migrate_legacy_messages(connection: sqlite3.Connection) -> None:
    legacy_exists = connection.execute(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'messages'"
    ).fetchone()
    if not legacy_exists:
        return

    rows = connection.execute("SELECT * FROM messages").fetchall()
    for row in rows:
        item_type = row["kind"]
        created_at = row["created_at"]
        connection.execute(
            """
            INSERT OR IGNORE INTO items (
                id, item_type, text, file_name, stored_name, file_url, preview_url, mime_type,
                sender, device_id, server_id, created_at, updated_at, deleted
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, 0)
            """,
            (
                row["id"],
                item_type,
                row["text"],
                row["file_name"],
                Path(row["file_url"] or "").name or None,
                row["file_url"],
                row["preview_url"] if "preview_url" in row.keys() else None,
                row["mime_type"],
                "ios" if row["sender"] == "iphone" else row["sender"],
                row["id"],
                created_at,
                created_at,
            ),
        )


def row_to_item(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "id": row["id"],
        "type": row["item_type"],
        "kind": row["item_type"],
        "text": row["text"],
        "fileName": row["file_name"],
        "storedName": row["stored_name"],
        "fileUrl": row["file_url"],
        "remoteFileUrl": row["file_url"],
        "previewUrl": row["preview_url"],
        "mimeType": row["mime_type"],
        "sender": row["sender"],
        "deviceId": row["device_id"],
        "serverId": row["server_id"] or row["id"],
        "createdAt": row["created_at"],
        "updatedAt": row["updated_at"],
        "syncStatus": "synced",
        "deleted": bool(row["deleted"]),
    }


def item_to_legacy_message(item: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": item["id"],
        "sender": item.get("sender") or "ios",
        "kind": item.get("type") or item.get("kind"),
        "text": item.get("text"),
        "fileName": item.get("fileName"),
        "fileUrl": item.get("fileUrl"),
        "previewUrl": item.get("previewUrl"),
        "mimeType": item.get("mimeType"),
        "createdAt": item.get("createdAt"),
    }


def get_item(item_id: str) -> dict[str, Any] | None:
    with database_connection() as connection:
        row = connection.execute("SELECT * FROM items WHERE id = ?", (item_id,)).fetchone()
    return row_to_item(row) if row else None


def store_processed_item(item_id: str, operation: str, metadata: dict[str, Any] | None = None) -> None:
    with database_connection() as connection:
        connection.execute(
            """
            INSERT OR REPLACE INTO processed_items (id, operation, processed_at, metadata)
            VALUES (?, ?, ?, ?)
            """,
            (item_id, operation, now_iso(), json.dumps(metadata or {}, ensure_ascii=False)),
        )
        connection.commit()


def upsert_item(payload: dict[str, Any], *, default_sender: str = "ios") -> tuple[dict[str, Any], bool, bool]:
    item_id = ensure_uuid(str(payload.get("id", "")))
    item_type = payload.get("type") or payload.get("kind") or "text"
    if item_type not in {"text", "link", "file", "media"}:
        raise HTTPException(status_code=400, detail="type must be text, link, file, or media")

    text = payload.get("text")
    if item_type == "text" and isinstance(text, str) and text.startswith(("http://", "https://")):
        item_type = "link"

    created_at = payload.get("createdAt") or payload.get("created_at") or now_iso()
    updated_at = payload.get("updatedAt") or payload.get("updated_at") or created_at
    sender = payload.get("sender") or default_sender
    device_id = payload.get("deviceId") or payload.get("device_id")
    file_url = payload.get("remoteFileUrl") or payload.get("fileUrl") or payload.get("file_url")
    stored_name = payload.get("storedName") or (Path(file_url).name if file_url else None)

    values = {
        "id": item_id,
        "item_type": item_type,
        "text": text,
        "file_name": payload.get("fileName") or payload.get("file_name"),
        "stored_name": stored_name,
        "file_url": file_url,
        "preview_url": payload.get("previewUrl") or payload.get("preview_url"),
        "mime_type": payload.get("mimeType") or payload.get("mime_type"),
        "sender": "ios" if sender == "iphone" else sender,
        "device_id": device_id,
        "server_id": payload.get("serverId") or item_id,
        "created_at": created_at,
        "updated_at": updated_at,
        "deleted": 1 if payload.get("deleted") else 0,
    }

    with database_connection() as connection:
        existing = connection.execute("SELECT * FROM items WHERE id = ?", (item_id,)).fetchone()
        duplicate = existing is not None
        changed = True

        if existing is None:
            connection.execute(
                """
                INSERT INTO items (
                    id, item_type, text, file_name, stored_name, file_url, preview_url, mime_type,
                    sender, device_id, server_id, created_at, updated_at, deleted
                )
                VALUES (
                    :id, :item_type, :text, :file_name, :stored_name, :file_url, :preview_url, :mime_type,
                    :sender, :device_id, :server_id, :created_at, :updated_at, :deleted
                )
                """,
                values,
            )
        elif parse_iso(updated_at) > parse_iso(existing["updated_at"]):
            connection.execute(
                """
                UPDATE items
                SET item_type = :item_type,
                    text = :text,
                    file_name = :file_name,
                    stored_name = COALESCE(:stored_name, stored_name),
                    file_url = COALESCE(:file_url, file_url),
                    preview_url = COALESCE(:preview_url, preview_url),
                    mime_type = COALESCE(:mime_type, mime_type),
                    sender = :sender,
                    device_id = COALESCE(:device_id, device_id),
                    server_id = :server_id,
                    updated_at = :updated_at,
                    deleted = :deleted
                WHERE id = :id
                """,
                values,
            )
        else:
            changed = False

        connection.execute(
            """
            INSERT OR REPLACE INTO processed_items (id, operation, processed_at, metadata)
            VALUES (?, ?, ?, ?)
            """,
            (item_id, "sync", now_iso(), json.dumps({"duplicate": duplicate}, ensure_ascii=False)),
        )
        connection.commit()
        row = connection.execute("SELECT * FROM items WHERE id = ?", (item_id,)).fetchone()

    return row_to_item(row), duplicate, changed


def is_heic_file(file_name: str, mime_type: str | None) -> bool:
    suffix = Path(file_name).suffix.lower()
    return suffix in {".heic", ".heif"} or mime_type in {
        "image/heic",
        "image/heif",
        "image/heic-sequence",
        "image/heif-sequence",
    }


def create_image_preview(source_path: Path, stored_name: str) -> str | None:
    if Image is None:
        return None

    preview_name = f"{Path(stored_name).stem}.png"
    preview_path = PREVIEWS_DIR / preview_name
    try:
        with Image.open(source_path) as image:
            image.thumbnail((1400, 1400))
            if image.mode not in {"RGB", "RGBA"}:
                image = image.convert("RGB")
            image.save(preview_path, "PNG", optimize=True)
        return f"/previews/{preview_name}"
    except Exception:
        if preview_path.exists():
            preview_path.unlink()
        logger.exception("Failed to generate image preview")
        return None


def ensure_preview_for_row(connection: sqlite3.Connection, row: sqlite3.Row) -> sqlite3.Row:
    if row["preview_url"] or not row["file_url"] or not is_heic_file(row["file_name"] or "", row["mime_type"]):
        return row

    stored_name = Path(row["file_url"]).name
    source_path = UPLOADS_DIR / stored_name
    if not source_path.exists():
        return row

    preview_url = create_image_preview(source_path, stored_name)
    if not preview_url:
        return row

    connection.execute(
        "UPDATE items SET preview_url = ?, mime_type = ?, updated_at = ? WHERE id = ?",
        (preview_url, row["mime_type"] or "image/heic", now_iso(), row["id"]),
    )
    connection.commit()
    return connection.execute("SELECT * FROM items WHERE id = ?", (row["id"],)).fetchone()


admin_sessions: dict[str, datetime] = {}
admin_sessions_lock = threading.Lock()


def same_host_addresses() -> set[str]:
    addresses = {"127.0.0.1", "::1", "localhost", get_lan_ip()}
    try:
        addresses.add(socket.gethostbyname(socket.gethostname()))
    except OSError:
        pass
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None):
            addresses.add(str(info[4][0]))
    except OSError:
        pass
    return {address.lower() for address in addresses if address}


def is_same_host_address(host: str | None) -> bool:
    if not host:
        return False
    normalized = host.strip().strip("[]").lower()
    return normalized in same_host_addresses()


def is_local_request(request: Request) -> bool:
    if not request.client:
        return False
    return is_same_host_address(request.client.host)


def prune_admin_sessions(current_time: datetime | None = None) -> None:
    timestamp = current_time or datetime.now(timezone.utc)
    expired = [token for token, expires_at in admin_sessions.items() if expires_at <= timestamp]
    for token in expired:
        admin_sessions.pop(token, None)


def create_admin_session() -> str:
    token = secrets.token_urlsafe(32)
    expires_at = datetime.now(timezone.utc) + timedelta(seconds=ADMIN_SESSION_TTL_SECONDS)
    with admin_sessions_lock:
        prune_admin_sessions()
        admin_sessions[token] = expires_at
    return token


def is_valid_admin_session(token: str | None) -> bool:
    if not token:
        return False
    with admin_sessions_lock:
        prune_admin_sessions()
        expires_at = admin_sessions.get(token)
        if not expires_at:
            return False
        if expires_at <= datetime.now(timezone.utc):
            admin_sessions.pop(token, None)
            return False
        return True


def admin_session_token_from_request(request: Request) -> str | None:
    return (
        request.headers.get(ADMIN_SESSION_HEADER)
        or request.cookies.get(ADMIN_SESSION_COOKIE)
        or request.query_params.get("admin_session")
        or request.query_params.get("adminSession")
    )


def is_admin_request(request: Request) -> bool:
    return is_local_request(request) or is_valid_admin_session(admin_session_token_from_request(request))


def admin_session_token_from_websocket(websocket: WebSocket) -> str | None:
    return (
        websocket.query_params.get("admin_session")
        or websocket.query_params.get("adminSession")
        or websocket.cookies.get(ADMIN_SESSION_COOKIE)
        or websocket.headers.get(ADMIN_SESSION_HEADER)
    )


def is_admin_websocket(websocket: WebSocket) -> bool:
    client_host = websocket.client.host if websocket.client else None
    return is_same_host_address(client_host) or is_valid_admin_session(admin_session_token_from_websocket(websocket))


def create_pairing_code() -> tuple[str, str]:
    code = f"{secrets.randbelow(1_000_000):06d}"
    created_at = datetime.now(timezone.utc)
    expires_at = created_at + timedelta(seconds=config.pairing_code_ttl_seconds)
    with database_connection() as connection:
        connection.execute("DELETE FROM pairing_codes")
        connection.execute(
            "INSERT INTO pairing_codes (code, created_at, expires_at) VALUES (?, ?, ?)",
            (code, created_at.isoformat(), expires_at.isoformat()),
        )
        connection.commit()
    return code, expires_at.isoformat()


def pairing_payload(code: str, expires_at: str) -> dict[str, Any]:
    lan_host = get_lan_ip()
    base = server_base_url()
    lan_base = server_base_url(lan_host)
    return {
        "type": "solodrop.pairing",
        "version": 1,
        "app": APP_NAME,
        "serverUrl": base,
        "lanServerUrl": lan_base,
        "pairVerifyUrl": f"{base}/pair/verify",
        "lanPairVerifyUrl": f"{lan_base}/pair/verify",
        "code": code,
        "pairCode": code,
        "expiresAt": expires_at,
        "host": config.public_host,
        "port": config.port,
        "manualEntry": f"{lan_host}:{config.port}",
        "httpsEnabled": config.https_enabled,
    }


def get_pairing_code_expiry(code: str) -> str | None:
    with database_connection() as connection:
        row = connection.execute("SELECT expires_at FROM pairing_codes WHERE code = ?", (code,)).fetchone()
    if not row:
        return None
    expires_at = row["expires_at"]
    if parse_iso(expires_at) < datetime.now(timezone.utc):
        return None
    return expires_at


def is_browser_device_name(device_name: str | None) -> bool:
    normalized = (device_name or "").strip().lower()
    return normalized in {"solodrop pc", "solodrop пк", "solodrop mac"}


def hash_device_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def is_device_whitelisted(device_id: str | None, device_token: str | None = None) -> bool:
    if not config.pairing_enabled:
        return True
    normalized_device_id = normalize_uuid(device_id)
    if not normalized_device_id:
        return False
    with database_connection() as connection:
        row = connection.execute(
            "SELECT device_id, token_hash FROM devices WHERE device_id = ?",
            (normalized_device_id,),
        ).fetchone()
        if row and row["token_hash"]:
            if not device_token or not hmac.compare_digest(hash_device_token(device_token), row["token_hash"]):
                return False
        if row:
            connection.execute(
                "UPDATE devices SET last_seen_at = ? WHERE device_id = ?",
                (now_iso(), normalized_device_id),
            )
            connection.commit()
        return row is not None


def require_device(device_id: str | None, device_token: str | None = None) -> None:
    if not is_device_whitelisted(device_id, device_token):
        raise HTTPException(status_code=403, detail="Device is not paired")


def require_remote_or_paired(request: Request, device_id: str | None, device_token: str | None = None) -> None:
    if is_admin_request(request):
        return
    require_device(device_id, device_token)


class WebSocketHub:
    def __init__(self) -> None:
        self.connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket) -> None:
        await websocket.accept()
        self.connections.append(websocket)

    def disconnect(self, websocket: WebSocket) -> None:
        if websocket in self.connections:
            self.connections.remove(websocket)

    async def broadcast_item(self, item: dict[str, Any]) -> None:
        await self.broadcast({"type": "item.upserted", "payload": item})

    async def broadcast_clear(self) -> None:
        await self.broadcast({"type": "items.cleared", "payload": {}})

    async def broadcast(self, payload_data: dict[str, Any]) -> None:
        payload = json.dumps(payload_data, ensure_ascii=False)
        dead_connections: list[WebSocket] = []
        for websocket in list(self.connections):
            try:
                await websocket.send_text(payload)
            except Exception:
                dead_connections.append(websocket)
        for websocket in dead_connections:
            self.disconnect(websocket)


class MDNSAdvertiser:
    refresh_interval_seconds = 15

    def __init__(self, settings: ServerConfig) -> None:
        self.settings = settings
        self.zeroconf: Any | None = None
        self.info: Any | None = None
        self.current_ip: str | None = None
        self.stop_event = threading.Event()
        self.lock = threading.Lock()
        self.monitor_thread: threading.Thread | None = None

    def start(self) -> None:
        if not self.settings.mdns_enabled:
            return
        if Zeroconf is None or ServiceInfo is None:
            logger.warning("zeroconf is not installed; mDNS discovery is disabled")
            return

        self.zeroconf = Zeroconf()
        if not self.register_current_ip():
            return

        self.stop_event.clear()
        self.monitor_thread = threading.Thread(
            target=self.monitor_ip_changes,
            name="solodrop-mdns-monitor",
            daemon=True,
        )
        self.monitor_thread.start()

    def register_current_ip(self) -> bool:
        ip = get_lan_ip()
        properties = {
            "app": APP_NAME,
            "version": APP_VERSION,
            "scheme": self.settings.scheme,
            "pairing": str(self.settings.pairing_enabled).lower(),
            "path": "/health",
            "stableHost": self.settings.public_host,
            "serverUrl": server_base_url(),
            "manualEntry": f"{ip}:{self.settings.port}",
        }
        info = ServiceInfo(
            self.settings.service_type,
            f"{self.settings.service_name}.{self.settings.service_type}",
            addresses=[socket.inet_aton(ip)],
            port=self.settings.port,
            properties=properties,
            server=mdns_hostname(self.settings.public_host),
        )

        if not self.zeroconf:
            self.zeroconf = Zeroconf()

        try:
            with self.lock:
                if self.info:
                    try:
                        self.zeroconf.unregister_service(self.info)
                    except Exception:
                        logger.debug("mDNS unregister before refresh failed", exc_info=True)
                self.zeroconf.register_service(info, allow_name_change=True)
                self.info = info
                self.current_ip = ip
        except Exception:
            logger.exception("mDNS registration failed; continuing without Bonjour discovery")
            if self.zeroconf:
                self.zeroconf.close()
                self.zeroconf = None
            self.info = None
            return False
        logger.info(
            "mDNS advertised as %s at %s (%s:%s)",
            self.settings.service_name,
            server_base_url(),
            ip,
            self.settings.port,
        )
        return True

    def monitor_ip_changes(self) -> None:
        while not self.stop_event.wait(self.refresh_interval_seconds):
            ip = get_lan_ip()
            if ip == self.current_ip:
                continue
            logger.info("LAN IP changed from %s to %s; refreshing mDNS record", self.current_ip, ip)
            self.register_current_ip()

    def stop(self) -> None:
        self.stop_event.set()
        if self.monitor_thread and self.monitor_thread.is_alive():
            self.monitor_thread.join(timeout=1)
        if self.zeroconf and self.info:
            with self.lock:
                try:
                    self.zeroconf.unregister_service(self.info)
                except Exception:
                    logger.debug("mDNS unregister during shutdown failed", exc_info=True)
                self.zeroconf.close()
        self.zeroconf = None
        self.info = None
        self.current_ip = None

    def status(self) -> dict[str, Any]:
        with self.lock:
            advertised = bool(self.zeroconf and self.info)
            current_ip = self.current_ip
        return {
            "enabled": self.settings.mdns_enabled,
            "available": Zeroconf is not None and ServiceInfo is not None,
            "advertised": advertised,
            "serviceName": self.settings.service_name,
            "serviceType": self.settings.service_type,
            "host": current_ip,
        }


hub = WebSocketHub()
mdns_advertiser = MDNSAdvertiser(config)


@asynccontextmanager
async def lifespan(_: FastAPI):
    initialize_database()
    await asyncio.to_thread(mdns_advertiser.start)
    try:
        yield
    finally:
        await asyncio.to_thread(mdns_advertiser.stop)


app = FastAPI(title=APP_NAME, version=APP_VERSION, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def add_no_cache_headers(request: Request, call_next):
    response = await call_next(request)
    if request.url.path == "/" or request.url.path.endswith((".html", ".css", ".js")):
        response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
    return response


initialize_database()


@app.get("/health")
def health() -> dict[str, Any]:
    return {"online": True, "app": APP_NAME, "version": APP_VERSION}


@app.get("/api/health")
def legacy_health() -> dict[str, Any]:
    return health()


@app.post("/admin/session")
def admin_session(response: Response) -> dict[str, Any]:
    token = create_admin_session()
    response.set_cookie(
        ADMIN_SESSION_COOKIE,
        token,
        max_age=ADMIN_SESSION_TTL_SECONDS,
        httponly=True,
        samesite="lax",
        secure=config.https_enabled,
    )
    return {
        "trusted": True,
        "sessionType": "admin",
        "adminSessionToken": token,
        "expiresInSeconds": ADMIN_SESSION_TTL_SECONDS,
    }


@app.get("/connect/config")
def connection_config() -> dict[str, Any]:
    ip = get_lan_ip()
    base = server_base_url()
    lan_base = server_base_url(ip)
    return {
        "app": APP_NAME,
        "version": APP_VERSION,
        "serverUrl": base,
        "healthUrl": f"{base}/health",
        "pairCodeUrl": f"{base}/pair/code",
        "pairVerifyUrl": f"{base}/pair/verify",
        "webSocketUrl": f"{config.websocket_scheme}://{config.public_host}:{config.port}/ws",
        "host": config.public_host,
        "port": config.port,
        "mdnsName": config.public_host,
        "stableHost": config.public_host,
        "lanServerUrl": lan_base,
        "lanHost": ip,
        "manualEntry": f"{ip}:{config.port}",
        "httpsEnabled": config.https_enabled,
        "bonjour": mdns_advertiser.status(),
    }


@app.get("/pair/qr")
def pair_qr(code: str | None = Query(default=None)) -> StreamingResponse:
    if config.pairing_enabled:
        if code:
            expires_at = get_pairing_code_expiry(code)
            if not expires_at:
                raise HTTPException(status_code=404, detail="Pairing code is not active")
        else:
            code, expires_at = create_pairing_code()
        payload = pairing_payload(code, expires_at)
    else:
        payload = connection_config()

    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=8,
        border=4,
    )
    qr.add_data(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    qr.make(fit=True)
    image = qr.make_image(fill_color="black", back_color="white")
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    buffer.seek(0)
    return StreamingResponse(buffer, media_type="image/png")


@app.get("/pair/code")
def pair_code() -> dict[str, Any]:
    if not config.pairing_enabled:
        return {"pairingEnabled": False, "code": None, "expiresAt": None, "pairingPayload": None, "qrUrl": None}

    code, expires_at = create_pairing_code()
    return {
        "pairingEnabled": True,
        "code": code,
        "expiresAt": expires_at,
        "pairingPayload": pairing_payload(code, expires_at),
        "qrUrl": f"/pair/qr?code={code}",
    }


@app.get("/pair/status")
def pair_status(
    request: Request,
    device_id: str | None = Query(default=None),
    device_token: str | None = Query(default=None),
) -> dict[str, Any]:
    normalized_device_id = normalize_uuid(device_id)
    if is_admin_request(request):
        return {
            "pairingEnabled": config.pairing_enabled,
            "paired": True,
            "trusted": True,
            "tokenValid": True,
            "deviceId": None,
            "device": None,
            "sessionType": "admin",
        }

    if not config.pairing_enabled:
        return {
            "pairingEnabled": False,
            "paired": True,
            "trusted": True,
            "tokenValid": True,
            "deviceId": normalized_device_id,
            "device": None,
            "sessionType": "device",
        }

    device: dict[str, Any] | None = None
    trusted = False
    token_valid = False
    if normalized_device_id:
        with database_connection() as connection:
            row = connection.execute(
                """
                SELECT device_id, device_name, token_hash, paired_at, last_seen_at
                FROM devices
                WHERE device_id = ?
                """,
                (normalized_device_id,),
            ).fetchone()
            if row:
                trusted = True
                token_hash = row["token_hash"]
                token_valid = not token_hash or bool(
                    device_token and hmac.compare_digest(hash_device_token(device_token), token_hash)
                )
                if token_valid:
                    connection.execute(
                        "UPDATE devices SET last_seen_at = ? WHERE device_id = ?",
                        (now_iso(), normalized_device_id),
                    )
                    connection.commit()
                device = {
                    "deviceId": row["device_id"],
                    "deviceName": row["device_name"],
                    "pairedAt": row["paired_at"],
                    "lastSeenAt": row["last_seen_at"],
                }

    return {
        "pairingEnabled": True,
        "paired": token_valid,
        "trusted": trusted,
        "tokenValid": token_valid,
        "deviceId": normalized_device_id,
        "device": device,
        "sessionType": "device",
    }


@app.post("/pair/verify")
def pair_verify(payload: dict[str, Any]) -> dict[str, Any]:
    if not config.pairing_enabled:
        return {"paired": True, "pairingEnabled": False}

    code = str(payload.get("code", "")).strip()
    device_id = ensure_uuid(str(payload.get("device_id") or payload.get("deviceId") or ""))
    device_name = str(payload.get("device_name") or payload.get("deviceName") or "iPhone")
    device_token = secrets.token_urlsafe(32)

    with database_connection() as connection:
        row = connection.execute("SELECT * FROM pairing_codes WHERE code = ?", (code,)).fetchone()
        if not row or parse_iso(row["expires_at"]) < datetime.now(timezone.utc):
            raise HTTPException(status_code=401, detail="Invalid or expired pairing code")

        timestamp = now_iso()
        connection.execute(
            """
            INSERT INTO devices (device_id, device_name, token_hash, paired_at, last_seen_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(device_id) DO UPDATE SET
                device_name = excluded.device_name,
                token_hash = excluded.token_hash,
                last_seen_at = excluded.last_seen_at
            """,
            (device_id, device_name, hash_device_token(device_token), timestamp, timestamp),
        )
        connection.execute("DELETE FROM pairing_codes WHERE code = ?", (code,))
        connection.commit()

    return {"paired": True, "deviceId": device_id, "deviceToken": device_token, "serverUrl": server_base_url()}


@app.get("/devices")
def list_devices() -> list[dict[str, Any]]:
    with database_connection() as connection:
        rows = connection.execute(
            "SELECT device_id, device_name, paired_at, last_seen_at FROM devices ORDER BY paired_at ASC"
        ).fetchall()
    return [dict(row) for row in rows if not is_browser_device_name(row["device_name"])]


@app.delete("/devices/{device_id}")
def forget_device(device_id: str) -> dict[str, Any]:
    device_id = ensure_uuid(device_id, "device_id")
    with database_connection() as connection:
        connection.execute("DELETE FROM devices WHERE device_id = ?", (device_id,))
        connection.commit()
    return {"forgotten": True, "deviceId": device_id}


@app.get("/api/messages")
def list_messages(limit: int = 300) -> list[dict[str, Any]]:
    limit = max(1, min(limit, 1000))
    with database_connection() as connection:
        rows = connection.execute(
            "SELECT * FROM items WHERE deleted = 0 ORDER BY created_at ASC LIMIT ?",
            (limit,),
        ).fetchall()
        rows = [ensure_preview_for_row(connection, row) for row in rows]
    return [item_to_legacy_message(row_to_item(row)) for row in rows]


@app.delete("/api/messages")
async def clear_messages(
    request: Request,
    device_id: str | None = Query(default=None),
    device_token: str | None = Query(default=None),
) -> dict[str, str]:
    require_remote_or_paired(request, device_id, device_token)
    with database_connection() as connection:
        connection.execute("DELETE FROM items")
        connection.execute("DELETE FROM processed_items")
        connection.commit()

    for directory in (UPLOADS_DIR, PREVIEWS_DIR):
        for path in directory.iterdir():
            if path.is_dir():
                shutil.rmtree(path)
            else:
                path.unlink()

    await hub.broadcast_clear()
    return {"status": "cleared"}


@app.post("/api/messages")
async def create_text_message(payload: dict[str, Any], request: Request) -> dict[str, Any]:
    device_id = payload.get("device_id") or payload.get("deviceId")
    device_token = payload.get("device_token") or payload.get("deviceToken")
    require_remote_or_paired(request, device_id, device_token)

    sender = "ios" if payload.get("sender") == "iphone" else payload.get("sender", "pc")
    text = str(payload.get("text", "")).strip()
    if sender not in {"pc", "ios"}:
        raise HTTPException(status_code=400, detail="sender must be pc or ios")
    if not text:
        raise HTTPException(status_code=400, detail="Text message is empty")

    item_id = str(payload.get("id") or uuid.uuid4())
    item_type = "link" if text.startswith(("http://", "https://")) else "text"
    item, _, _ = upsert_item(
        {
            "id": item_id,
            "type": item_type,
            "text": text,
            "sender": sender,
            "deviceId": device_id,
            "createdAt": payload.get("createdAt") or now_iso(),
            "updatedAt": payload.get("updatedAt") or now_iso(),
        },
        default_sender=sender,
    )
    await hub.broadcast_item(item)
    return item_to_legacy_message(item)


@app.post("/api/files")
async def create_file_message(
    request: Request,
    sender: str = Form(default="pc"),
    device_id: str | None = Form(default=None),
    device_token: str | None = Form(default=None),
    client_item_id: str | None = Form(default=None),
    uploaded_file: UploadFile = File(...),
) -> dict[str, Any]:
    require_remote_or_paired(request, device_id, device_token)
    item_id = client_item_id or str(uuid.uuid4())
    result = await save_uploaded_file(
        item_id=item_id,
        upload=uploaded_file,
        device_id=device_id,
        sender="ios" if sender == "iphone" else sender,
    )
    await hub.broadcast_item(result["item"])
    return item_to_legacy_message(result["item"])


@app.post("/upload")
async def upload_file(
    request: Request,
    client_item_id: str = Form(...),
    device_id: str = Form(...),
    device_token: str | None = Form(default=None),
    file: UploadFile = File(...),
    created_at: str | None = Form(default=None),
    updated_at: str | None = Form(default=None),
) -> dict[str, Any]:
    require_remote_or_paired(request, device_id, device_token)
    result = await save_uploaded_file(
        item_id=client_item_id,
        upload=file,
        device_id=device_id,
        sender="ios",
        created_at=created_at,
        updated_at=updated_at,
    )
    if not result["duplicate"]:
        await hub.broadcast_item(result["item"])
    return {
        "processed": True,
        "duplicate": result["duplicate"],
        "clientItemId": result["item"]["id"],
        "metadata": result["item"],
    }


async def save_uploaded_file(
    *,
    item_id: str,
    upload: UploadFile,
    device_id: str | None,
    sender: str,
    created_at: str | None = None,
    updated_at: str | None = None,
) -> dict[str, Any]:
    item_id = ensure_uuid(item_id, "client_item_id")
    existing = get_item(item_id)
    if existing and existing.get("fileUrl"):
        store_processed_item(item_id, "upload", {"duplicate": True})
        return {"item": existing, "duplicate": True}

    original_name = safe_name(upload.filename)
    extension = Path(original_name).suffix
    stored_name = f"{item_id}{extension}"
    stored_path = UPLOADS_DIR / stored_name

    if not stored_path.exists():
        with stored_path.open("wb") as destination:
            while True:
                chunk = await upload.read(1024 * 1024)
                if not chunk:
                    break
                destination.write(chunk)

    mime_type = upload.content_type or mimetypes.guess_type(original_name)[0] or "application/octet-stream"
    preview_url = create_image_preview(stored_path, stored_name) if is_heic_file(original_name, mime_type) else None
    if preview_url and mime_type == "application/octet-stream":
        mime_type = "image/heic"

    timestamp = now_iso()
    item, duplicate, _ = upsert_item(
        {
            "id": item_id,
            "type": "file",
            "fileName": original_name,
            "storedName": stored_name,
            "fileUrl": f"/files/{stored_name}",
            "previewUrl": preview_url,
            "mimeType": mime_type,
            "sender": sender,
            "deviceId": device_id,
            "createdAt": created_at or timestamp,
            "updatedAt": updated_at or timestamp,
        },
        default_sender=sender,
    )
    store_processed_item(item_id, "upload", {"duplicate": duplicate})
    return {"item": item, "duplicate": duplicate}


@app.get("/files/{stored_name}")
def download_file(stored_name: str) -> FileResponse:
    path = UPLOADS_DIR / safe_name(stored_name)
    if not path.exists():
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(path)


@app.get("/previews/{preview_name}")
def preview_file(preview_name: str) -> FileResponse:
    path = PREVIEWS_DIR / safe_name(preview_name)
    if not path.exists():
        raise HTTPException(status_code=404, detail="Preview not found")
    return FileResponse(path, media_type="image/png")


@app.post("/sync/push")
async def sync_push(payload: dict[str, Any], request: Request) -> dict[str, Any]:
    device_id = payload.get("device_id") or payload.get("deviceId")
    device_token = payload.get("device_token") or payload.get("deviceToken")
    require_remote_or_paired(request, device_id, device_token)

    items = payload.get("items")
    if not isinstance(items, list):
        raise HTTPException(status_code=400, detail="items must be a list")

    processed: list[str] = []
    results: list[dict[str, Any]] = []
    changed_items: list[dict[str, Any]] = []
    for raw_item in items:
        if not isinstance(raw_item, dict):
            continue
        raw_item.setdefault("deviceId", device_id)
        item, duplicate, changed = upsert_item(raw_item, default_sender="ios")
        processed.append(item["id"])
        results.append({"id": item["id"], "duplicate": duplicate, "item": item})
        if changed:
            changed_items.append(item)

    for item in changed_items:
        await hub.broadcast_item(item)

    return {
        "processed_item_ids": processed,
        "processedItemIds": processed,
        "results": results,
        "serverTime": now_iso(),
    }


@app.get("/sync/pull")
def sync_pull(
    request: Request,
    device_id: str = Query(...),
    device_token: str | None = Query(default=None),
    since: str | None = Query(default=None),
    cursor: str | None = Query(default=None),
    limit: int = Query(default=500, ge=1, le=1000),
) -> dict[str, Any]:
    require_remote_or_paired(request, device_id, device_token)

    since_value = cursor or since or "1970-01-01T00:00:00+00:00"
    with database_connection() as connection:
        rows = connection.execute(
            """
            SELECT * FROM items
            WHERE updated_at > ?
            ORDER BY updated_at ASC
            LIMIT ?
            """,
            (since_value, limit),
        ).fetchall()
        rows = [ensure_preview_for_row(connection, row) for row in rows]

    items = [row_to_item(row) for row in rows]
    next_cursor = items[-1]["updatedAt"] if items else since_value
    return {"items": items, "cursor": next_cursor, "serverTime": now_iso()}


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> None:
    device_id = websocket.query_params.get("device_id") or websocket.query_params.get("deviceId")
    device_token = websocket.query_params.get("device_token") or websocket.query_params.get("deviceToken")
    if not is_admin_websocket(websocket) and not is_device_whitelisted(device_id, device_token):
        await websocket.close(code=1008)
        return

    await hub.connect(websocket)
    try:
        while True:
            message = await websocket.receive_text()
            try:
                payload = json.loads(message)
            except json.JSONDecodeError:
                payload = {"type": "text", "payload": message}
            if payload.get("type") == "ping":
                await websocket.send_text(json.dumps({"type": "pong", "payload": {"serverTime": now_iso()}}))
    except WebSocketDisconnect:
        hub.disconnect(websocket)
    except Exception:
        hub.disconnect(websocket)
        logger.exception("WebSocket client disconnected after an unexpected error")


app.mount("/", StaticFiles(directory=STATIC_DIR, html=True), name="static")


def uvicorn_kwargs() -> dict[str, Any]:
    kwargs: dict[str, Any] = {"host": config.host, "port": config.port}
    if config.https_enabled:
        cert_path = config.resolve_path(config.cert_path)
        key_path = config.resolve_path(config.key_path)
        if not cert_path.exists() or not key_path.exists():
            raise RuntimeError("HTTPS is enabled but cert/key files are missing.")
        kwargs["ssl_certfile"] = str(cert_path)
        kwargs["ssl_keyfile"] = str(key_path)
    return kwargs


if __name__ == "__main__":
    import uvicorn

    if not config.https_enabled:
        logger.warning("Starting in development HTTP mode. Production should set https_enabled=true.")
    uvicorn.run("main:app", **uvicorn_kwargs())
