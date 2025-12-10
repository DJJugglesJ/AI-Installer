import json
import subprocess
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _start_server(directory: Path):
    handler = partial(SimpleHTTPRequestHandler, directory=str(directory))
    server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server, thread


def test_checksum_failure_emits_structured_status(tmp_path):
    server_dir = tmp_path / "server"
    server_dir.mkdir()
    (server_dir / "file.bin").write_text("hello", encoding="utf-8")

    server, thread = _start_server(server_dir)
    port = server.server_address[1]

    status_file = tmp_path / "status.jsonl"
    log_file = tmp_path / "download.log"
    script = f"""
set -euo pipefail
source "{ROOT}/modules/shell/downloads/download_helpers.sh"
DOWNLOAD_STATUS_FILE="{status_file}"
DOWNLOAD_LOG_FILE="{log_file}"
log_msg() {{ download_log "$1"; }}
download_with_retries "http://127.0.0.1:{port}/file.bin" "{tmp_path / 'out.bin'}" "invalid" ""
"""

    result = subprocess.run(["bash", "-lc", script], cwd=ROOT, capture_output=True, text=True)
    server.shutdown()
    thread.join(timeout=5)

    assert result.returncode != 0
    events = []
    for line in status_file.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    assert any(event.get("event") == "checksum_failed" for event in events)
    assert any(event.get("event") == "download_failed" for event in events)
    assert log_file.exists()
