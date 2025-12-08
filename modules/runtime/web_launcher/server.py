"""Lightweight web launcher that wraps existing shell helpers and runtime modules.

- Purpose: expose HTTP endpoints for launcher/install commands, manifest browsing,
  and prompt compilation while serving the bundled web UI.
- Assumptions: repository layout matches the documented modules/ and manifests/
  directories; Python runtime can import the runtime packages.
- Side effects: writes prompt bundles to the cache path, spawns shell helper
  processes, and reads manifest/character data for display in the UI.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import threading
from dataclasses import asdict, dataclass
from datetime import datetime
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple
from urllib.parse import urlparse

from modules.runtime.character_studio.registry import CharacterCardRegistry
from modules.runtime.prompt_builder import compiler
from modules.runtime.prompt_builder.services import UIIntegrationHooks


@dataclass
class ActionSpec:
    """Describe a launcher action that shells out to existing helpers."""

    id: str
    label: str
    description: str
    command: List[str]


class WebLauncherAPI:
    """Backend helpers for the web launcher HTTP surface."""

    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.modules_dir = project_root / "modules"
        self.shell_dir = self.modules_dir / "shell"
        self.manifest_dir = project_root / "manifests"
        self._ui_hooks = UIIntegrationHooks()
        self._card_registry = CharacterCardRegistry()
        self._action_map: Dict[str, ActionSpec] = self._build_action_map()
        self._log_dir = Path.home() / ".cache/aihub/web_launcher/logs"
        self._log_dir.mkdir(parents=True, exist_ok=True)

    def _build_action_map(self) -> Dict[str, ActionSpec]:
        actions: Iterable[Tuple[str, str, str, str]] = (
            ("run_webui", "Run Stable Diffusion WebUI", "Launch the Stable Diffusion WebUI stack", "run_webui.sh"),
            ("run_kobold", "Launch KoboldAI", "Start KoboldAI with existing models", "run_kobold.sh"),
            ("run_sillytavern", "Launch SillyTavern", "Start SillyTavern with configured backends", "run_sillytavern.sh"),
            ("install_loras", "Install or Update LoRAs", "Download curated or CivitAI LoRAs", "install_loras.sh"),
            ("install_models", "Install or Update Models", "Install curated or Hugging Face models", "install_models.sh"),
            ("manifest_browser", "Browse Curated Manifests", "Run the legacy manifest browser flow", "manifest_browser.sh"),
            ("artifact_maintenance", "Artifact Maintenance", "Prune caches and verify model/LoRA links", "artifact_manager.sh"),
            ("self_update", "Update Installer", "Run the built-in self-update to refresh scripts", "self_update.sh"),
        )

        action_map: Dict[str, ActionSpec] = {}
        for action_id, label, description, script_name in actions:
            script_path = self.shell_dir / script_name
            action_map[action_id] = ActionSpec(
                id=action_id,
                label=label,
                description=description,
                command=["bash", str(script_path)],
            )
        return action_map

    def list_actions(self) -> List[Dict[str, str]]:
        return [asdict(action) for action in self._action_map.values()]

    def trigger_action(self, action_id: str) -> Dict[str, object]:
        if action_id not in self._action_map:
            raise ValueError(f"Unknown action: {action_id}")

        action = self._action_map[action_id]
        timestamp = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
        log_path = self._log_dir / f"{action_id}-{timestamp}.log"
        with log_path.open("w", encoding="utf-8") as log_file:
            process = subprocess.Popen(
                action.command,
                cwd=self.project_root,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                env={**os.environ, "HEADLESS": "1"},
            )

        return {
            "action": action.id,
            "pid": process.pid,
            "log_path": str(log_path),
            "command": action.command,
            "started_at": timestamp,
        }

    def _load_manifest(self, name: str) -> Dict[str, object]:
        manifest_path = self.manifest_dir / f"{name}.json"
        if not manifest_path.exists():
            return {"source": None, "items": []}
        payload = json.loads(manifest_path.read_text(encoding="utf-8"))
        return {"source": payload.get("source"), "items": payload.get("items", [])}

    def get_manifests(self) -> Dict[str, object]:
        return {"models": self._load_manifest("models"), "loras": self._load_manifest("loras")}

    def list_characters(self) -> List[Dict[str, object]]:
        cards: List[Dict[str, object]] = []
        for card_id in self._card_registry.list_ids():
            card = self._card_registry.find(card_id)
            if card:
                cards.append(card.to_dict())
        return cards

    def compile_prompt(self, scene_json: Dict[str, object]) -> Dict[str, object]:
        assembly = compiler.build_prompt_from_scene(scene_json)
        payload = assembly.to_payload()
        published = self._ui_hooks.publish_prompt(assembly)
        return {"assembly": payload, "published": published}

    def status(self) -> Dict[str, object]:
        manifests = self.get_manifests()
        return {
            "actions": self.list_actions(),
            "manifest_counts": {
                "models": len(manifests.get("models", {}).get("items", [])),
                "loras": len(manifests.get("loras", {}).get("items", [])),
            },
            "characters": len(self.list_characters()),
        }


class LauncherRequestHandler(SimpleHTTPRequestHandler):
    """Serve static assets and JSON APIs for the web launcher."""

    def __init__(self, *args, api: WebLauncherAPI, static_dir: Path, **kwargs):
        self.api = api
        super().__init__(*args, directory=str(static_dir), **kwargs)

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        if parsed.path.startswith("/api/"):
            self._handle_api_get(parsed.path)
            return
        super().do_GET()

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        if parsed.path.startswith("/api/"):
            self._handle_api_post(parsed.path)
            return
        self.send_error(HTTPStatus.NOT_FOUND, "Unsupported POST path")

    def _read_json_body(self) -> Dict:
        length_header = self.headers.get("Content-Length", "0")
        content_length = int(length_header) if length_header.isdigit() else 0
        raw_body = self.rfile.read(content_length) if content_length else b""
        if not raw_body:
            return {}
        return json.loads(raw_body.decode("utf-8"))

    def _send_json(self, payload: Dict, status: HTTPStatus = HTTPStatus.OK) -> None:
        response = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(response)))
        self.end_headers()
        self.wfile.write(response)

    def _handle_api_get(self, path: str) -> None:
        try:
            if path == "/api/status":
                self._send_json(self.api.status())
            elif path == "/api/manifests":
                self._send_json(self.api.get_manifests())
            elif path == "/api/characters":
                self._send_json({"items": self.api.list_characters()})
            elif path == "/api/actions":
                self._send_json({"items": self.api.list_actions()})
            else:
                self.send_error(HTTPStatus.NOT_FOUND, "Unknown API endpoint")
        except Exception as exc:  # pragma: no cover - defensive routing guard
            self._send_json({"error": str(exc)}, status=HTTPStatus.INTERNAL_SERVER_ERROR)

    def _handle_api_post(self, path: str) -> None:
        try:
            if path == "/api/actions":
                payload = self._read_json_body()
                action_id = payload.get("action")
                result = self.api.trigger_action(action_id)
                self._send_json(result, status=HTTPStatus.ACCEPTED)
            elif path == "/api/prompt/compile":
                payload = self._read_json_body()
                scene_payload = payload.get("scene", payload)
                result = self.api.compile_prompt(scene_payload)
                self._send_json(result)
            else:
                self.send_error(HTTPStatus.NOT_FOUND, "Unknown API endpoint")
        except ValueError as exc:
            self._send_json({"error": str(exc)}, status=HTTPStatus.BAD_REQUEST)
        except Exception as exc:  # pragma: no cover - defensive routing guard
            self._send_json({"error": str(exc)}, status=HTTPStatus.INTERNAL_SERVER_ERROR)

    def log_message(self, format: str, *args) -> None:  # noqa: A003
        # Keep launcher output minimal; rely on action log files instead.
        return


def run_server(host: str = "127.0.0.1", port: int = 3939) -> None:
    """Start the threaded HTTP server for the web launcher."""

    project_root = Path(__file__).resolve().parents[3]
    static_dir = Path(__file__).parent / "static"
    api = WebLauncherAPI(project_root=project_root)

    def handler(*args, **kwargs):
        return LauncherRequestHandler(*args, api=api, static_dir=static_dir, **kwargs)

    server = ThreadingHTTPServer((host, port), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    print(f"AI Hub web launcher running on http://{host}:{port}")
    try:
        thread.join()
    except KeyboardInterrupt:
        print("Shutting down web launcher...")
        server.shutdown()


def main() -> None:
    parser = argparse.ArgumentParser(description="AI Hub web launcher")
    parser.add_argument("--host", default=os.environ.get("AIHUB_WEB_HOST", "127.0.0.1"), help="Bind host")
    parser.add_argument("--port", type=int, default=int(os.environ.get("AIHUB_WEB_PORT", "3939")), help="Bind port")
    args = parser.parse_args()
    run_server(host=args.host, port=args.port)


if __name__ == "__main__":
    main()
