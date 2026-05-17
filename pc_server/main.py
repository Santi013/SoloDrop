from __future__ import annotations

import json
import mimetypes
import shutil
import sqlite3
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import FastAPI, File, Form, HTTPException, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

try:
    from PIL import Image
    from pillow_heif import register_heif_opener

    register_heif_opener()
except ImportError:
    Image = None


BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
UPLOADS_DIR = DATA_DIR / "uploads"
PREVIEWS_DIR = DATA_DIR / "previews"
DATABASE_PATH = DATA_DIR / "messages.sqlite3"

DATA_DIR.mkdir(exist_ok=True)
UPLOADS_DIR.mkdir(exist_ok=True)
PREVIEWS_DIR.mkdir(exist_ok=True)

app = FastAPI(title="Local Saved Messages")
mimetypes.add_type("image/heic", ".heic")
mimetypes.add_type("image/heif", ".heif")

# Разрешаем запросы из браузера и iOS-приложения в локальной сети.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def add_no_cache_headers(request, call_next):
    response = await call_next(request)
    if request.url.path == "/" or request.url.path.endswith((".html", ".css", ".js")):
        response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
    return response


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def database_connection() -> sqlite3.Connection:
    connection = sqlite3.connect(DATABASE_PATH)
    connection.row_factory = sqlite3.Row
    return connection


def initialize_database() -> None:
    with database_connection() as connection:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY,
                sender TEXT NOT NULL,
                kind TEXT NOT NULL,
                text TEXT,
                file_name TEXT,
                file_url TEXT,
                preview_url TEXT,
                mime_type TEXT,
                created_at TEXT NOT NULL
            )
            """
        )
        columns = {row["name"] for row in connection.execute("PRAGMA table_info(messages)").fetchall()}
        if "preview_url" not in columns:
            connection.execute("ALTER TABLE messages ADD COLUMN preview_url TEXT")
        connection.commit()


def row_to_message(row: sqlite3.Row) -> dict[str, Any]:
    sender = "ios" if row["sender"] == "iphone" else row["sender"]
    return {
        "id": row["id"],
        "sender": sender,
        "kind": row["kind"],
        "text": row["text"],
        "fileName": row["file_name"],
        "fileUrl": row["file_url"],
        "previewUrl": row["preview_url"],
        "mimeType": row["mime_type"],
        "createdAt": row["created_at"],
    }


def insert_message(
    *,
    sender: str,
    kind: str,
    text: str | None = None,
    file_name: str | None = None,
    file_url: str | None = None,
    preview_url: str | None = None,
    mime_type: str | None = None,
) -> dict[str, Any]:
    message = {
        "id": str(uuid.uuid4()),
        "sender": sender,
        "kind": kind,
        "text": text,
        "file_name": file_name,
        "file_url": file_url,
        "preview_url": preview_url,
        "mime_type": mime_type,
        "created_at": now_iso(),
    }
    with database_connection() as connection:
        connection.execute(
            """
            INSERT INTO messages (id, sender, kind, text, file_name, file_url, preview_url, mime_type, created_at)
            VALUES (:id, :sender, :kind, :text, :file_name, :file_url, :preview_url, :mime_type, :created_at)
            """,
            message,
        )
        connection.commit()

    with database_connection() as connection:
        row = connection.execute(
            "SELECT * FROM messages WHERE id = ?",
            (message["id"],),
        ).fetchone()
    return row_to_message(row)


def is_heic_file(file_name: str, mime_type: str | None) -> bool:
    suffix = Path(file_name).suffix.lower()
    return suffix in {".heic", ".heif"} or mime_type in {"image/heic", "image/heif", "image/heic-sequence", "image/heif-sequence"}


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
        "UPDATE messages SET preview_url = ?, mime_type = ? WHERE id = ?",
        (preview_url, row["mime_type"] or "image/heic", row["id"]),
    )
    connection.commit()
    return connection.execute("SELECT * FROM messages WHERE id = ?", (row["id"],)).fetchone()


class WebSocketHub:
    def __init__(self) -> None:
        self.connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket) -> None:
        await websocket.accept()
        self.connections.append(websocket)

    def disconnect(self, websocket: WebSocket) -> None:
        if websocket in self.connections:
            self.connections.remove(websocket)

    async def broadcast_message(self, message: dict[str, Any]) -> None:
        await self.broadcast({"type": "message", "message": message})

    async def broadcast_clear(self) -> None:
        await self.broadcast({"type": "clear"})

    async def broadcast(self, payload_data: dict[str, Any]) -> None:
        payload = json.dumps(payload_data)
        dead_connections: list[WebSocket] = []
        for websocket in self.connections:
            try:
                await websocket.send_text(payload)
            except Exception:
                dead_connections.append(websocket)
        for websocket in dead_connections:
            self.disconnect(websocket)


hub = WebSocketHub()
initialize_database()


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/messages")
def list_messages(limit: int = 300) -> list[dict[str, Any]]:
    limit = max(1, min(limit, 1000))
    with database_connection() as connection:
        rows = connection.execute(
            "SELECT * FROM messages ORDER BY created_at ASC LIMIT ?",
            (limit,),
        ).fetchall()
        rows = [ensure_preview_for_row(connection, row) for row in rows]
    return [row_to_message(row) for row in rows]


@app.delete("/api/messages")
async def clear_messages() -> dict[str, str]:
    with database_connection() as connection:
        connection.execute("DELETE FROM messages")
        connection.commit()

    for path in UPLOADS_DIR.iterdir():
        if path.is_dir():
            shutil.rmtree(path)
        else:
            path.unlink()
    for path in PREVIEWS_DIR.iterdir():
        if path.is_dir():
            shutil.rmtree(path)
        else:
            path.unlink()

    await hub.broadcast_clear()
    return {"status": "cleared"}


@app.post("/api/messages")
async def create_text_message(payload: dict[str, str]) -> dict[str, Any]:
    sender = "ios" if payload.get("sender") == "iphone" else payload.get("sender", "pc")
    text = payload.get("text", "").strip()
    if sender not in {"pc", "ios"}:
        raise HTTPException(status_code=400, detail="sender должен быть pc или ios")
    if not text:
        raise HTTPException(status_code=400, detail="Текст сообщения пустой")

    kind = "link" if text.startswith(("http://", "https://")) else "text"
    message = insert_message(sender=sender, kind=kind, text=text)
    await hub.broadcast_message(message)
    return message


@app.post("/api/files")
async def create_file_message(
    sender: str = Form(default="pc"),
    uploaded_file: UploadFile = File(...),
) -> dict[str, Any]:
    sender = "ios" if sender == "iphone" else sender
    if sender not in {"pc", "ios"}:
        raise HTTPException(status_code=400, detail="sender должен быть pc или ios")

    original_name = Path(uploaded_file.filename or "file").name
    extension = Path(original_name).suffix
    stored_name = f"{uuid.uuid4()}{extension}"
    stored_path = UPLOADS_DIR / stored_name

    content = await uploaded_file.read()
    stored_path.write_bytes(content)

    mime_type = uploaded_file.content_type or mimetypes.guess_type(original_name)[0] or "application/octet-stream"
    preview_url = create_image_preview(stored_path, stored_name) if is_heic_file(original_name, mime_type) else None
    if preview_url and mime_type == "application/octet-stream":
        mime_type = "image/heic"
    message = insert_message(
        sender=sender,
        kind="file",
        file_name=original_name,
        file_url=f"/files/{stored_name}",
        preview_url=preview_url,
        mime_type=mime_type,
    )
    await hub.broadcast_message(message)
    return message


@app.get("/files/{stored_name}")
def download_file(stored_name: str) -> FileResponse:
    safe_name = Path(stored_name).name
    path = UPLOADS_DIR / safe_name
    if not path.exists():
        raise HTTPException(status_code=404, detail="Файл не найден")
    return FileResponse(path)


@app.get("/previews/{preview_name}")
def preview_file(preview_name: str) -> FileResponse:
    safe_name = Path(preview_name).name
    path = PREVIEWS_DIR / safe_name
    if not path.exists():
        raise HTTPException(status_code=404, detail="Превью не найдено")
    return FileResponse(path, media_type="image/png")


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> None:
    await hub.connect(websocket)
    try:
        while True:
            # Клиент может присылать ping/любой текст. Основной поток идет через REST API.
            await websocket.receive_text()
    except WebSocketDisconnect:
        hub.disconnect(websocket)


app.mount("/", StaticFiles(directory=BASE_DIR / "static", html=True), name="static")
