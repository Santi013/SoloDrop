from __future__ import annotations

import contextlib
import fcntl
import html
import json
import os
import shutil
import socket
import sys
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

import uvicorn
import webview

APP_NAME = "SoloDrop"
READY_TIMEOUT_SECONDS = 30
WINDOW_WIDTH = 1180
WINDOW_HEIGHT = 760

_lock_file: Any | None = None
_server: uvicorn.Server | None = None
_server_thread: threading.Thread | None = None
_owns_server = False


def app_support_dir() -> Path:
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / APP_NAME
    return Path.home() / f".{APP_NAME.lower()}"


def configure_runtime_dir() -> Path:
    runtime_dir = app_support_dir()
    runtime_dir.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("SOLODROP_RUNTIME_DIR", str(runtime_dir))
    migrate_legacy_bundle_runtime(runtime_dir)
    return runtime_dir


def migrate_legacy_bundle_runtime(runtime_dir: Path) -> None:
    if not getattr(sys, "frozen", False):
        return

    legacy_dir = Path(sys.executable).resolve().parent
    if legacy_dir == runtime_dir:
        return

    for filename in ("config.json",):
        source = legacy_dir / filename
        destination = runtime_dir / filename
        if source.exists() and not destination.exists():
            shutil.copy2(source, destination)

    for dirname in ("data", "uploads", "previews"):
        source = legacy_dir / dirname
        destination = runtime_dir / dirname
        if source.exists() and not destination.exists():
            shutil.copytree(source, destination)


RUNTIME_DIR = configure_runtime_dir()

from main import app as server_app  # noqa: E402
from main import config, uvicorn_kwargs  # noqa: E402


def local_url(path: str = "") -> str:
    prefix = path if path.startswith("/") or not path else f"/{path}"
    return f"{config.scheme}://127.0.0.1:{config.port}{prefix}"


def health_is_ready() -> bool:
    try:
        with urllib.request.urlopen(local_url("/health"), timeout=0.8) as response:
            payload = json.loads(response.read().decode("utf-8"))
            return response.status == 200 and payload.get("app") == APP_NAME
    except (OSError, ValueError, urllib.error.URLError):
        return False


def port_is_open() -> bool:
    try:
        with socket.create_connection(("127.0.0.1", config.port), timeout=0.5):
            return True
    except OSError:
        return False


def acquire_single_instance_lock() -> bool:
    global _lock_file
    lock_path = RUNTIME_DIR / "SoloDrop.lock"
    _lock_file = lock_path.open("a+")
    try:
        fcntl.flock(_lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return False
    return True


def release_single_instance_lock() -> None:
    if _lock_file is None:
        return
    with contextlib.suppress(OSError):
        fcntl.flock(_lock_file.fileno(), fcntl.LOCK_UN)
    with contextlib.suppress(OSError):
        _lock_file.close()


def start_server() -> None:
    global _owns_server, _server, _server_thread
    if health_is_ready():
        return
    if port_is_open():
        raise RuntimeError("SoloDrop port is in use, but the server health check did not respond.")

    kwargs = uvicorn_kwargs()
    kwargs["access_log"] = False
    uvicorn_config = uvicorn.Config(server_app, **kwargs)
    _server = uvicorn.Server(uvicorn_config)
    _server_thread = threading.Thread(target=_server.run, name="solodrop-server", daemon=True)
    _owns_server = True
    _server_thread.start()


def wait_until_ready(timeout_seconds: int = READY_TIMEOUT_SECONDS) -> bool:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        if health_is_ready():
            return True
        if _server_thread is not None and not _server_thread.is_alive():
            return False
        time.sleep(0.25)
    return False


def stop_server() -> None:
    if _server is not None and _owns_server:
        _server.should_exit = True
    if _server_thread is not None and _server_thread.is_alive():
        _server_thread.join(timeout=5)


def status_html(title: str, message: str, *, is_error: bool = False) -> str:
    accent = "#c2410c" if is_error else "#2563eb"
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
:root {{
  color-scheme: light dark;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  background: Canvas;
  color: CanvasText;
}}
body {{
  margin: 0;
  min-height: 100vh;
  display: grid;
  place-items: center;
}}
main {{
  width: min(520px, calc(100vw - 48px));
  border: 1px solid color-mix(in srgb, CanvasText 16%, transparent);
  border-radius: 8px;
  padding: 28px;
}}
h1 {{
  margin: 0 0 12px;
  font-size: 24px;
  line-height: 1.2;
}}
p {{
  margin: 0;
  font-size: 15px;
  line-height: 1.5;
}}
.mark {{
  width: 40px;
  height: 40px;
  border-radius: 8px;
  margin-bottom: 18px;
  background: {accent};
}}
</style>
</head>
<body>
<main>
<div class="mark" aria-hidden="true"></div>
<h1>{html.escape(title)}</h1>
<p>{html.escape(message)}</p>
</main>
</body>
</html>"""


def launch(window: webview.Window) -> None:
    try:
        start_server()
    except Exception as exc:
        window.load_html(
            status_html(
                "SoloDrop cannot start",
                f"{exc}",
                is_error=True,
            )
        )
        return

    if wait_until_ready():
        window.load_url(local_url())
        return

    window.load_html(
        status_html(
            "SoloDrop is not responding",
            "The local server started but did not become ready in time.",
            is_error=True,
        )
    )


def main() -> int:
    webview_storage_dir = RUNTIME_DIR / "WebView"
    webview_storage_dir.mkdir(parents=True, exist_ok=True)

    if not acquire_single_instance_lock():
        window = webview.create_window(
            APP_NAME,
            html=status_html(
                "SoloDrop is already running",
                "Use the existing SoloDrop window from the Dock.",
            ),
            width=560,
            height=360,
            resizable=False,
        )
        webview.start(
            lambda: threading.Timer(2.0, window.destroy).start(),
            private_mode=False,
            storage_path=str(webview_storage_dir),
        )
        return 0

    window = webview.create_window(
        APP_NAME,
        html=status_html("SoloDrop", "Starting local server..."),
        width=WINDOW_WIDTH,
        height=WINDOW_HEIGHT,
        min_size=(840, 560),
    )
    try:
        webview.start(
            launch,
            (window,),
            private_mode=False,
            storage_path=str(webview_storage_dir),
        )
    finally:
        stop_server()
        release_single_instance_lock()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
