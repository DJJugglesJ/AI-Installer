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


def _load_events(status_file: Path):
    events = []
    if not status_file.exists():
        return events
    for line in status_file.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return events


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
    events = _load_events(status_file)
    assert any(event.get("event") == "checksum_failed" for event in events)
    assert any(event.get("event") == "download_failed" for event in events)
    assert log_file.exists()


def test_mirror_failover_and_selection(tmp_path):
    server_dir = tmp_path / "server"
    server_dir.mkdir()
    payload = b"mirror success"
    target_file = server_dir / "file.bin"
    target_file.write_bytes(payload)

    server, thread = _start_server(server_dir)
    port = server.server_address[1]

    status_file = tmp_path / "status.jsonl"
    log_file = tmp_path / "download.log"
    dest = tmp_path / "out.bin"
    checksum = subprocess.check_output(["sha256sum", str(target_file)]).decode().split()[0]

    mirror_list = f"http://127.0.0.1:9/file.bin\nhttp://127.0.0.1:{port}/file.bin"
    script = f"""
set -euo pipefail
source "{ROOT}/modules/shell/downloads/download_helpers.sh"
DOWNLOAD_STATUS_FILE="{status_file}"
DOWNLOAD_LOG_FILE="{log_file}"
download_with_retries "http://127.0.0.1:9/file.bin" "{dest}" "" "{checksum}" "{mirror_list}"
"""

    result = subprocess.run(["bash", "-lc", script], cwd=ROOT, capture_output=True, text=True)
    server.shutdown()
    thread.join(timeout=5)

    assert result.returncode == 0
    events = _load_events(status_file)
    assert any(event.get("event") == "mirror_fallback" for event in events)
    assert any(event.get("event") == "mirror_selected" and str(event.get("detail", {})).find(str(port)) != -1 for event in events)
    assert dest.read_bytes() == payload


def test_offline_bundle_validation_and_skip(tmp_path):
    offline_dir = tmp_path / "offline"
    offline_dir.mkdir()
    offline_file = offline_dir / "out.bin"
    offline_file.write_bytes(b"offline-copy")
    checksum = subprocess.check_output(["sha256sum", str(offline_file)]).decode().split()[0]

    status_file = tmp_path / "status.jsonl"
    log_file = tmp_path / "download.log"
    dest = tmp_path / "out.bin"

    script = f"""
set -euo pipefail
source "{ROOT}/modules/shell/downloads/download_helpers.sh"
DOWNLOAD_STATUS_FILE="{status_file}"
DOWNLOAD_LOG_FILE="{log_file}"
DOWNLOAD_OFFLINE_BUNDLE="{offline_dir}"
download_with_retries "http://127.0.0.1:9/unreachable.bin" "{dest}" "" "{checksum}" ""
"""

    result = subprocess.run(["bash", "-lc", script], cwd=ROOT, capture_output=True, text=True)

    assert result.returncode == 0
    assert dest.exists()
    assert dest.read_bytes() == offline_file.read_bytes()
    events = _load_events(status_file)
    assert any(event.get("event") == "offline_used" for event in events)
    assert not any(event.get("event") == "download_failed" for event in events)
