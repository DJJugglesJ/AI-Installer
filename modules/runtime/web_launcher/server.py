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
import re
from dataclasses import asdict, dataclass, field
from datetime import datetime
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple
from urllib.parse import urlparse

from modules.config_service import config_service
from modules.runtime.character_studio.registry import CharacterCardRegistry
from modules.runtime.hardware.gpu_diagnostics import collect_gpu_diagnostics
from modules.runtime.prompt_builder import compiler
from modules.runtime.prompt_builder.services import UIIntegrationHooks
from modules.runtime.registry import get_tool, list_tools, load_default_tools
from modules.runtime.models.tasks import serialize_task, Task
from modules.runtime.audio.tts import services as tts_services
from modules.runtime.audio.asr import services as asr_services
from modules.runtime.audio.voice_profiles import services as voice_profiles_services
from modules.runtime.video.img2vid import services as img2vid_services
from modules.runtime.video.txt2vid import services as txt2vid_services


logger = logging.getLogger(__name__)


def _slugify(value: str) -> str:
    normalized = re.sub(r"[^a-zA-Z0-9]+", "-", value.strip().lower())
    return normalized.strip("-")


PAIRING_SCHEMA: Dict[str, object] = {
    "type": "object",
    "properties": {
        "model": {"type": "string"},
        "loras": {"type": "array", "items": {"type": "string"}},
    },
    "additionalProperties": False,
}


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
    status_path: Optional[Path] = None
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

    def to_dict(self, log_tail: str = "", events: Optional[List[Dict[str, object]]] = None) -> Dict[str, object]:
        return {
            "id": self.id,
            "models": self.models,
            "loras": self.loras,
            "command": self.command,
            "log_path": str(self.log_path),
            "status_path": str(self.status_path) if self.status_path else "",
            "started_at": self.started_at,
            "completed_at": self.completed_at,
            "status": self.status,
            "returncode": self.returncode,
            "log_tail": log_tail,
            "events": events or [],
        }


class WebLauncherAPI:
    """Backend helpers for the web launcher HTTP surface."""

    def __init__(
        self,
        project_root: Path,
        config_path: Optional[Path] = None,
        log_dir: Optional[Path] = None,
        history_path: Optional[Path] = None,
    ):
        self.project_root = project_root
        self.modules_dir = project_root / "modules"
        self.shell_dir = self.modules_dir / "shell"
        self.manifest_dir = project_root / "manifests"
        self.config_path = config_path or Path(config_service.DEFAULT_CONFIG_PATH)
        self._ui_hooks = UIIntegrationHooks()
        self._card_registry = CharacterCardRegistry()
        self._action_map: Dict[str, ActionSpec] = self._build_action_map()
        self._log_dir = log_dir or Path.home() / ".cache/aihub/web_launcher/logs"
        self._history_path = history_path or Path.home() / ".cache/aihub/web_launcher/selection_history.json"
        self._log_dir.mkdir(parents=True, exist_ok=True)
        self._history_path.parent.mkdir(parents=True, exist_ok=True)
        self._install_jobs: Dict[str, InstallJob] = {}
        self._tasks: Dict[str, Task] = {}
        self._lock = threading.Lock()
        load_default_tools()

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
            message = f"Manifest {manifest_path.name} not found"
            return {**base_payload, "errors": [message], "has_errors": True}

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

        validated_items: List[Dict[str, object]] = []
        for idx, item in enumerate(items):
            if not isinstance(item, dict):
                message = f"{manifest_path.name} items[{idx}] is not an object"
                logger.warning(message)
                errors.append(message)
                continue

            entry = dict(item)
            entry.setdefault("tags", [])
            entry.setdefault("license", "")
            entry.setdefault("notes", "")
            entry.setdefault("version", "")
            entry.setdefault("size_bytes", None)
            entry.setdefault("checksum", "")

            issues: List[str] = []
            name_value = entry.get("name")
            if not isinstance(name_value, str) or not name_value.strip():
                issues.append("Manifest entries must include a name")
            entry_slug = entry.get("slug") or (name_value and _slugify(name_value))
            entry["slug"] = entry_slug or ""
            if not entry["slug"]:
                issues.append("Manifest entries must include a slug or valid name")

            if not entry.get("url") and not entry.get("filename"):
                issues.append("Entries should include a download url or filename")
            if not isinstance(entry.get("tags"), list):
                issues.append("tags must be a list")
                entry["tags"] = []

            entry["health"] = "ok" if not issues else "warning"
            entry["issues"] = issues
            if issues:
                errors.extend([f"{manifest_path.name} {entry['name'] or entry['slug']}: {msg}" for msg in issues])

            validated_items.append(entry)

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

    def list_manifest(self, manifest_type: str) -> Dict[str, object]:
        if manifest_type not in {"models", "loras"}:
            raise ValueError("Manifest type must be 'models' or 'loras'")
        manifest = self._load_manifest(manifest_type)
        manifest["type"] = manifest_type
        return manifest

    def get_manifest_item(self, manifest_type: str, item_id: str) -> Dict[str, object]:
        manifest = self.list_manifest(manifest_type)
        index = {item.get("slug") or _slugify(item.get("name", "")): item for item in manifest.get("items", [])}
        normalized = _slugify(item_id)
        if normalized not in index:
            raise ValueError(f"Manifest item '{item_id}' not found in {manifest_type}")
        return {"item": index[normalized], "type": manifest_type, "source": manifest.get("source"), "errors": manifest.get("errors", [])}

    def _tail_log(self, log_path: Path, lines: int = 20) -> str:
        if not log_path.exists():
            return ""
        with log_path.open("r", encoding="utf-8", errors="ignore") as handle:
            content = handle.readlines()
        if len(content) <= lines:
            return "".join(content)
        return "".join(content[-lines:])

    def _append_status_event(
        self, path: Path, level: str, event: str, message: str, detail: Optional[object] = None
    ) -> None:
        payload: Dict[str, object] = {
            "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
            "level": level,
            "event": event,
            "message": message,
        }
        if detail is not None:
            payload["detail"] = detail

        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(payload))
            handle.write("\n")

    def _load_status_events(self, path: Path, limit: int = 50) -> List[Dict[str, object]]:
        if not path or not path.exists():
            return []

        events: List[Dict[str, object]] = []
        with path.open("r", encoding="utf-8", errors="ignore") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    events.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
        return events[-limit:]

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
        if job.status_path:
            level = "info" if job.returncode == 0 else "error"
            message = "Installer completed successfully" if job.returncode == 0 else "Installer failed"
            self._append_status_event(job.status_path, level, "installer_completed", message, {"returncode": job.returncode})
        with self._lock:
            self._install_jobs[job.id] = job
        self._record_history(job)

    def _start_job(self, *, models: List[str], loras: List[str], script_name: str) -> InstallJob:
        job_id = f"{Path(script_name).stem}-{uuid.uuid4().hex[:8]}"
        log_path = self._log_dir / f"{job_id}.log"
        status_path = self._log_dir / f"{job_id}.status.jsonl"
        if status_path.exists():
            status_path.unlink()
        env = {
            **os.environ,
            "HEADLESS": "1",
            "DOWNLOAD_STATUS_FILE": str(status_path),
            "DOWNLOAD_LOG_FILE": str(log_path),
        }

        if models:
            env["CURATED_MODEL_NAMES"] = "\n".join(models)
        if loras:
            env["CURATED_LORA_NAMES"] = "\n".join(loras)

        self._append_status_event(
            status_path,
            "info",
            "installer_started",
            f"Starting {script_name}",
            {"models": models, "loras": loras},
        )

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
            status_path=status_path,
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
            events = self._load_status_events(job.status_path)
            job_dict = job.to_dict(
                log_tail=self._tail_log(job.log_path),
                events=events,
            )
            job_dict["last_error"] = next((ev for ev in reversed(events) if ev.get("level") == "error"), None)
            job_dict["last_mirror"] = next(
                (ev for ev in reversed(events) if ev.get("event") in {"mirror_selected", "offline_used"}),
                None,
            )
            rendered_jobs.append(job_dict)

        return {
            "jobs": rendered_jobs,
            "history": self._load_history(),
        }

    def _load_config(self) -> Dict[str, object]:
        loaded = config_service.load_config(str(self.config_path), env_prefix="", overrides=[])
        if loaded.migrated:
            config_service.save_config(loaded.data, str(self.config_path))
        return loaded.data

    def _save_selection(self, selection: Dict[str, object]) -> Dict[str, object]:
        config = self._load_config()
        config_service.deep_set(config, "selection", selection)
        config_service.save_config(config, str(self.config_path))
        return selection

    def get_pairings(self) -> Dict[str, object]:
        config = self._load_config()
        selection = config.get("selection", {})
        return {
            "selection": {
                "model": selection.get("model", ""),
                "loras": selection.get("loras", []),
            },
            "manifests": {
                "models": self.list_manifest("models"),
                "loras": self.list_manifest("loras"),
            },
        }

    def update_pairings(self, payload: Dict[str, object]) -> Dict[str, object]:
        errors = config_service.validate_against_schema(payload, PAIRING_SCHEMA)
        if errors:
            raise ValueError("; ".join(errors))

        selection_model = str(payload.get("model", "")).strip()
        selection_loras = payload.get("loras", []) or []
        if not isinstance(selection_loras, list):
            raise ValueError("loras must be a list of names")

        manifests = self.get_manifests()
        model_index = {item.get("name"): item for item in manifests.get("models", {}).get("items", [])}
        lora_index = {item.get("name"): item for item in manifests.get("loras", {}).get("items", [])}

        if selection_model and selection_model not in model_index:
            raise ValueError(f"Unknown model '{selection_model}'")

        invalid_loras = [name for name in selection_loras if name not in lora_index]
        if invalid_loras:
            raise ValueError(f"Unknown LoRA entries: {', '.join(invalid_loras)}")

        unique_loras = []
        for name in selection_loras:
            if name not in unique_loras:
                unique_loras.append(name)

        selection = {"model": selection_model, "loras": unique_loras}
        saved = self._save_selection(selection)
        return {"selection": saved}

    def list_characters(self) -> List[Dict[str, object]]:
        cards: List[Dict[str, object]] = []
        for card_id in self._card_registry.list_ids():
            card = self._card_registry.find(card_id)
            if card:
                cards.append(card.to_dict())
        return cards

    def list_tools(self) -> Dict[str, object]:
        tools = [tool.to_dict() for tool in list_tools()]
        available = [tool for tool in tools if tool.get("available")]
        return {"items": tools, "available_count": len(available), "total": len(tools)}

    def create_task(self, tool_id: str, payload: Dict[str, object]) -> Dict[str, object]:
        tool = get_tool(tool_id)
        if not tool:
            raise ValueError(f"Unknown tool: {tool_id}")
        if not tool.available:
            raise ValueError(tool.availability_error or f"Tool {tool_id} is unavailable")

        if tool_id == "tts":
            task = tts_services.run_text_to_speech_from_payload(payload)
        elif tool_id == "asr":
            task = asr_services.run_asr_from_payload(payload)
        elif tool_id == "voice_profiles":
            task = voice_profiles_services.list_voice_profiles()
        elif tool_id == "img2vid":
            task = img2vid_services.run_img2vid_from_payload(payload)
        elif tool_id == "txt2vid":
            task = txt2vid_services.run_txt2vid_from_payload(payload)
        else:
            raise ValueError(f"Tool {tool_id} is not yet wired to the launcher")

        with self._lock:
            self._tasks[task.id] = task
        return serialize_task(task)

    def list_tasks(self) -> Dict[str, object]:
        with self._lock:
            tasks = [serialize_task(task) for task in self._tasks.values()]
        return {"items": tasks}

    def compile_prompt(self, scene_json: Dict[str, object], feedback: Optional[str] = None) -> Dict[str, object]:
        if not isinstance(scene_json, dict):
            raise ValueError("scene must be a JSON object")
        if feedback is not None and not isinstance(feedback, str):
            raise ValueError("feedback must be a string when provided")

        compiled_scene = scene_json if feedback is None else compiler.apply_feedback_to_scene(scene_json, feedback)
        assembly = compiler.build_prompt_from_scene(compiled_scene)
        assembly_payload = assembly.to_payload()
        published = self._ui_hooks.publish_prompt(assembly)
        return {"assembly": assembly_payload, "published": published}

    def apply_feedback(self, scene_json: Dict[str, object], feedback: str) -> Dict[str, object]:
        if not isinstance(scene_json, dict):
            raise ValueError("scene must be a JSON object")
        updated = compiler.apply_feedback_to_scene(scene_json, feedback)
        return {"scene": updated}

    def status(self) -> Dict[str, object]:
        manifests = self.get_manifests()
        return {
            "actions": self.list_actions(),
            "manifest_counts": {
                "models": len(manifests.get("models", {}).get("items", [])),
                "loras": len(manifests.get("loras", {}).get("items", [])),
            },
            "characters": len(self.list_characters()),
            "tools": self.list_tools(),
        }

    def gpu_diagnostics(self) -> Dict[str, object]:
        script_path = self.shell_dir / "gpu_diagnostics.sh"
        env = {**os.environ, "HEADLESS": "1"}
        if script_path.exists():
            try:
                result = subprocess.run(
                    ["bash", str(script_path)],
                    check=False,
                    capture_output=True,
                    text=True,
                    cwd=self.project_root,
                    env=env,
                )
                if result.returncode == 0 and result.stdout.strip():
                    return json.loads(result.stdout)
                logger.warning("GPU diagnostics helper returned %s", result.returncode)
            except json.JSONDecodeError:
                logger.warning("Failed to decode GPU diagnostics JSON; falling back to runtime collector")
            except OSError as exc:
                logger.warning("GPU diagnostics helper invocation failed: %s", exc)
        return collect_gpu_diagnostics()


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
            if path.startswith("/api/manifests/"):
                _, _, manifest_type, *rest = path.strip("/").split("/")
                if rest:
                    self._send_json(self.api.get_manifest_item(manifest_type, rest[0]))
                else:
                    self._send_json(self.api.list_manifest(manifest_type))
                return
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
            elif path == "/api/tools":
                self._send_json(self.api.list_tools())
            elif path == "/api/tasks":
                self._send_json(self.api.list_tasks())
            elif path in {"/api/hardware/gpu", "/api/hardware/gpu/diagnostics"}:
                self._send_json(self.api.gpu_diagnostics())
            elif path == "/api/pairings":
                self._send_json(self.api.get_pairings())
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
                feedback = payload.get("feedback")
                result = self.api.compile_prompt(scene_payload, feedback)
                self._send_json(result)
            elif path == "/api/prompt/feedback":
                payload = self._read_json_body()
                scene_payload = payload.get("scene", payload)
                feedback = payload.get("feedback", "")
                result = self.api.apply_feedback(scene_payload, feedback)
                self._send_json(result)
            elif path == "/api/installations":
                payload = self._read_json_body()
                models = payload.get("models", [])
                loras = payload.get("loras", [])
                jobs = self.api.start_installation(models=models, loras=loras)
                self._send_json({"jobs": jobs}, status=HTTPStatus.ACCEPTED)
            elif path == "/api/tasks":
                payload = self._read_json_body()
                tool_id = payload.get("tool")
                task_payload = payload.get("payload", payload)
                task = self.api.create_task(tool_id, task_payload)
                self._send_json({"task": task}, status=HTTPStatus.ACCEPTED)
            elif path == "/api/pairings":
                payload = self._read_json_body()
                result = self.api.update_pairings(payload)
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
