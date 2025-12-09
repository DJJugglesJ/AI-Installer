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
import logging
import os
import subprocess
import threading
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple
from urllib.parse import urlparse

from modules.runtime.character_studio.registry import CharacterCardRegistry
from modules.runtime.prompt_builder import compiler
from modules.runtime.prompt_builder.services import UIIntegrationHooks


logger = logging.getLogger(__name__)


@dataclass
class ActionSpec:
    """Describe a launcher action that shells out to existing helpers."""

    id: str
    label: str
    description: str
    command: List[str]


@dataclass
class InstallJob:
    """Track a running or finished installer invocation."""

    id: str
    models: List[str] = field(default_factory=list)
    loras: List[str] = field(default_factory=list)
    command: List[str] = field(default_factory=list)
    log_path: Path = Path()
    started_at: str = ""
    completed_at: Optional[str] = None
    returncode: Optional[int] = None
    process: Optional[subprocess.Popen] = None

    @property
    def status(self) -> str:
        if self.returncode is None and self.process and self.process.poll() is None:
            return "running"
        if self.returncode == 0:
            return "succeeded"
        if self.returncode is not None:
            return "failed"
        return "unknown"

    def to_dict(self, log_tail: str = "") -> Dict[str, object]:
        return {
            "id": self.id,
            "models": self.models,
            "loras": self.loras,
            "command": self.command,
            "log_path": str(self.log_path),
            "started_at": self.started_at,
            "completed_at": self.completed_at,
            "status": self.status,
            "returncode": self.returncode,
            "log_tail": log_tail,
        }


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
        self._history_path = Path.home() / ".cache/aihub/web_launcher/selection_history.json"
        self._log_dir.mkdir(parents=True, exist_ok=True)
        self._history_path.parent.mkdir(parents=True, exist_ok=True)
        self._install_jobs: Dict[str, InstallJob] = {}
        self._lock = threading.Lock()

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
        base_payload = {"source": None, "items": [], "errors": [], "has_errors": False}
        if not manifest_path.exists():
            return base_payload

        try:
            payload = json.loads(manifest_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            message = f"Failed to parse {manifest_path.name}: {exc}"
            logger.warning(message)
            return {**base_payload, "errors": [message], "has_errors": True}

        if not isinstance(payload, dict):
            message = f"Manifest {manifest_path.name} must be a JSON object"
            logger.warning(message)
            return {**base_payload, "errors": [message], "has_errors": True}

        errors: List[str] = []
        source = payload.get("source")
        items = payload.get("items", [])

        if not isinstance(items, list):
            message = f"Manifest {manifest_path.name} items must be a list"
            logger.warning(message)
            return {**base_payload, "source": source, "errors": [message], "has_errors": True}

        required_keys = ("name", "model_id", "source")
        validated_items: List[Dict[str, object]] = []
        for idx, item in enumerate(items):
            if not isinstance(item, dict):
                message = f"{manifest_path.name} items[{idx}] is not an object"
                logger.warning(message)
                errors.append(message)
                continue

            missing_keys = [key for key in required_keys if not isinstance(item.get(key), str) or not item.get(key)]
            if missing_keys:
                message = (
                    f"{manifest_path.name} items[{idx}] missing or invalid keys: "
                    f"{', '.join(sorted(missing_keys))}"
                )
                logger.warning(message)
                errors.append(message)
                continue

            validated_items.append(item)

        return {
            "source": source,
            "items": validated_items,
            "errors": errors,
            "has_errors": bool(errors),
        }

    def get_manifests(self) -> Dict[str, object]:
        models_manifest = self._load_manifest("models")
        loras_manifest = self._load_manifest("loras")
        errors = models_manifest.get("errors", []) + loras_manifest.get("errors", [])
        return {
            "models": models_manifest,
            "loras": loras_manifest,
            "errors": errors,
            "has_errors": bool(errors),
        }

    def _tail_log(self, log_path: Path, lines: int = 20) -> str:
        if not log_path.exists():
            return ""
        with log_path.open("r", encoding="utf-8", errors="ignore") as handle:
            content = handle.readlines()
        if len(content) <= lines:
            return "".join(content)
        return "".join(content[-lines:])

    def _load_history(self) -> List[Dict[str, object]]:
        if not self._history_path.exists():
            return []
        try:
            return json.loads(self._history_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return []

    def _write_history(self, history: List[Dict[str, object]]) -> None:
        self._history_path.write_text(json.dumps(history, indent=2), encoding="utf-8")

    def _record_history(self, job: InstallJob) -> None:
        history = self._load_history()
        history.insert(
            0,
            {
                "id": job.id,
                "models": job.models,
                "loras": job.loras,
                "status": job.status,
                "log_path": str(job.log_path),
                "started_at": job.started_at,
                "completed_at": job.completed_at,
            },
        )
        self._write_history(history[:20])

    def _monitor_job(self, job: InstallJob) -> None:
        if not job.process:
            return
        job.returncode = job.process.wait()
        job.completed_at = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
        with self._lock:
            self._install_jobs[job.id] = job
        self._record_history(job)

    def _start_job(self, *, models: List[str], loras: List[str], script_name: str) -> InstallJob:
        job_id = f"{Path(script_name).stem}-{uuid.uuid4().hex[:8]}"
        log_path = self._log_dir / f"{job_id}.log"
        env = {
            **os.environ,
            "HEADLESS": "1",
        }

        if models:
            env["CURATED_MODEL_NAMES"] = "\n".join(models)
        if loras:
            env["CURATED_LORA_NAMES"] = "\n".join(loras)

        process = subprocess.Popen(
            ["bash", str(self.shell_dir / script_name)],
            cwd=self.project_root,
            stdout=log_path.open("w", encoding="utf-8"),
            stderr=subprocess.STDOUT,
            env=env,
        )

        job = InstallJob(
            id=job_id,
            models=models,
            loras=loras,
            command=["bash", str(self.shell_dir / script_name)],
            log_path=log_path,
            started_at=datetime.utcnow().strftime("%Y%m%dT%H%M%SZ"),
            process=process,
        )

        monitor = threading.Thread(target=self._monitor_job, args=(job,), daemon=True)
        monitor.start()
        with self._lock:
            self._install_jobs[job.id] = job
        return job

    def start_installation(self, models: Optional[List[str]] = None, loras: Optional[List[str]] = None) -> List[Dict[str, object]]:
        models = models or []
        loras = loras or []
        if not models and not loras:
            raise ValueError("At least one model or LoRA name must be provided")

        jobs: List[InstallJob] = []
        if models:
            jobs.append(self._start_job(models=models, loras=[], script_name="install_models.sh"))
        if loras:
            jobs.append(self._start_job(models=[], loras=loras, script_name="install_loras.sh"))

        return [job.to_dict() for job in jobs]

    def list_installations(self) -> Dict[str, object]:
        with self._lock:
            jobs = list(self._install_jobs.values())

        rendered_jobs: List[Dict[str, object]] = []
        for job in jobs:
            if job.process and job.returncode is None:
                job.returncode = job.process.poll()
                if job.returncode is not None and job.completed_at is None:
                    job.completed_at = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
                    self._record_history(job)
            rendered_jobs.append(job.to_dict(log_tail=self._tail_log(job.log_path)))

        return {
            "jobs": rendered_jobs,
            "history": self._load_history(),
        }

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

    def __init__(self, *args, api: WebLauncherAPI, static_dir: Path, auth_token: Optional[str], **kwargs):
        self.api = api
        self.auth_token = auth_token
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

    def _is_authorized(self) -> bool:
        if not self.auth_token:
            return True
        expected = f"Bearer {self.auth_token}"
        header = self.headers.get("Authorization", "")
        alt_header = self.headers.get("X-AIHUB-TOKEN", "")
        return header == expected or alt_header == self.auth_token

    def _require_auth(self) -> bool:
        if self._is_authorized():
            return True
        self._send_json({"error": "Unauthorized"}, status=HTTPStatus.UNAUTHORIZED)
        return False

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
        if not self._require_auth():
            return
        try:
            if path == "/api/status":
                self._send_json(self.api.status())
            elif path == "/api/manifests":
                self._send_json(self.api.get_manifests())
            elif path == "/api/characters":
                self._send_json({"items": self.api.list_characters()})
            elif path == "/api/actions":
                self._send_json({"items": self.api.list_actions()})
            elif path == "/api/installations":
                self._send_json(self.api.list_installations())
            else:
                self.send_error(HTTPStatus.NOT_FOUND, "Unknown API endpoint")
        except Exception as exc:  # pragma: no cover - defensive routing guard
            self._send_json({"error": str(exc)}, status=HTTPStatus.INTERNAL_SERVER_ERROR)

    def _handle_api_post(self, path: str) -> None:
        if not self._require_auth():
            return
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
            elif path == "/api/installations":
                payload = self._read_json_body()
                models = payload.get("models", [])
                loras = payload.get("loras", [])
                jobs = self.api.start_installation(models=models, loras=loras)
                self._send_json({"jobs": jobs}, status=HTTPStatus.ACCEPTED)
            else:
                self.send_error(HTTPStatus.NOT_FOUND, "Unknown API endpoint")
        except ValueError as exc:
            self._send_json({"error": str(exc)}, status=HTTPStatus.BAD_REQUEST)
        except Exception as exc:  # pragma: no cover - defensive routing guard
            self._send_json({"error": str(exc)}, status=HTTPStatus.INTERNAL_SERVER_ERROR)

    def log_message(self, format: str, *args) -> None:  # noqa: A003
        # Keep launcher output minimal; rely on action log files instead.
        return


def run_server(host: str = "127.0.0.1", port: int = 3939, auth_token: Optional[str] = None) -> None:
    """Start the threaded HTTP server for the web launcher."""

    project_root = Path(__file__).resolve().parents[3]
    static_dir = Path(__file__).parent / "static"
    api = WebLauncherAPI(project_root=project_root)

    def handler(*args, **kwargs):
        return LauncherRequestHandler(
            *args, api=api, static_dir=static_dir, auth_token=auth_token, **kwargs
        )

    server = ThreadingHTTPServer((host, port), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    token_note = " with bearer token auth" if auth_token else ""
    print(f"AI Hub web launcher running on http://{host}:{port}{token_note}")
    try:
        thread.join()
    except KeyboardInterrupt:
        print("Shutting down web launcher...")
        server.shutdown()


def main() -> None:
    parser = argparse.ArgumentParser(description="AI Hub web launcher")
    subparsers = parser.add_subparsers(dest="command")

    serve_parser = subparsers.add_parser("serve", help="Run the web launcher server")
    serve_parser.add_argument("--host", default=os.environ.get("AIHUB_WEB_HOST", "127.0.0.1"), help="Bind host")
    serve_parser.add_argument("--port", type=int, default=int(os.environ.get("AIHUB_WEB_PORT", "3939")), help="Bind port")
    serve_parser.add_argument(
        "--auth-token",
        default=os.environ.get("AIHUB_WEB_TOKEN"),
        help="Optional bearer token required for API requests",
    )

    install_parser = subparsers.add_parser("install", help="Trigger curated installs without the UI")
    install_parser.add_argument("--models", nargs="*", default=[], help="Curated model names to install")
    install_parser.add_argument("--loras", nargs="*", default=[], help="Curated LoRA names to install")
    install_parser.add_argument("--wait", action="store_true", help="Block until installers complete")

    args = parser.parse_args()
    command = args.command or "serve"

    project_root = Path(__file__).resolve().parents[3]

    if command == "serve":
        run_server(
            host=getattr(args, "host", "127.0.0.1"),
            port=getattr(args, "port", 3939),
            auth_token=getattr(args, "auth_token", None),
        )
        return

    if command == "install":
        api = WebLauncherAPI(project_root=project_root)
        jobs = api.start_installation(models=args.models, loras=args.loras)
        print(json.dumps({"jobs": jobs}, indent=2))
        if not args.wait:
            return

        # Simple progress loop while blocking
        job_ids = {job["id"] for job in jobs}
        while True:
            current = api.list_installations()
            active = []
            for job in current.get("jobs", []):
                if job["id"] not in job_ids:
                    continue
                print(
                    f"[{job['status']}] {job['id']} models={job.get('models', [])} loras={job.get('loras', [])}\n"
                    f"Log tail:\n{job.get('log_tail', '').strip()}\n---"
                )
                if job["status"] == "running":
                    active.append(job)
            if not active:
                break
            threading.Event().wait(3)
        return

    parser.print_help()


if __name__ == "__main__":
    main()
