from __future__ import annotations

import sys
from pathlib import Path

import uvicorn

from main import config, get_lan_ip, server_base_url, uvicorn_kwargs


def main() -> int:
    ip = get_lan_ip()
    base_url = server_base_url(ip)
    print("SoloDrop Server")
    print(f"Local URL: {base_url}")
    print(f"Health:    {base_url}/health")
    print(f"Pair PIN:  {base_url}/pair/code")
    print(f"QR PNG:    {base_url}/pair/qr")
    print("")

    if not config.https_enabled:
        print("WARNING: running in HTTP development mode. Enable HTTPS for production.")

    try:
        uvicorn.run("main:app", **uvicorn_kwargs())
    except RuntimeError as exc:
        print(f"Startup error: {exc}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        return 0
    return 0


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    raise SystemExit(main())
