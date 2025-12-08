"""Windows-friendly launcher for AI Hub actions.

Mirrors the actions exposed by `aihub_menu.sh` while avoiding YAD
dependencies. Provides lightweight GPU detection, manifest lookups,
and a consistent log sink for actions triggered from Windows PowerShell
or Command Prompt wrappers.
"""
from __future__ import annotations

"""Windows-friendly entry point for AI Hub launcher actions.

Provides a headless-friendly shim around the `aihub_menu.sh` options so
Windows users (or WSL sessions without YAD) can trigger installs,
launchers, and maintenance flows. Logs to the same installer log as the
Linux shell scripts and surfaces manifest counts and GPU detection in a
lightweight way.
"""

import argparse
import json
import os
import platform
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SHELL_DIR = PROJECT_ROOT / "modules" / "shell"
LAUNCHER_DIR = PROJECT_ROOT / "launcher"
MANIFEST_DIR = PROJECT_ROOT / "manifests"


def _default_log_path() -> Path:
    override = os.environ.get("AIHUB_LOG_PATH")
    if override:
        return Path(override).expanduser()
    if platform.system().lower().startswith("windows"):
        local_appdata = os.environ.get("LOCALAPPDATA")
        if local_appdata:
            return Path(local_appdata) / "AIHub" / "logs" / "install.log"
    return Path.home() / ".config" / "aihub" / "install.log"


LOG_PATH = _default_log_path()
LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
LOG_PATH.touch(exist_ok=True)


class ActionSpec:
    """Describe an action and how to execute it."""

    def __init__(
        self,
        action_id: str,
        description: str,
        command: Optional[List[str]] = None,
        env: Optional[Dict[str, str]] = None,
        python_module: Optional[Tuple[str, List[str]]] = None,
    ) -> None:
        self.id = action_id
        self.description = description
        self.command = command or []
        self.env = env or {}
        self.python_module = python_module


ACTION_MAP: Dict[str, ActionSpec] = {
    "run_webui": ActionSpec("run_webui", "Start the Stable Diffusion WebUI stack", ["bash", str(SHELL_DIR / "run_webui.sh")]),
    "performance_flags": ActionSpec(
        "performance_flags", "Toggle FP16/xFormers/DirectML flags", ["bash", str(SHELL_DIR / "performance_flags.sh")]
    ),
    "run_kobold": ActionSpec("run_kobold", "Launch KoboldAI", ["bash", str(SHELL_DIR / "run_kobold.sh")]),
    "run_sillytavern": ActionSpec("run_sillytavern", "Launch SillyTavern", ["bash", str(SHELL_DIR / "run_sillytavern.sh")]),
    "install_loras": ActionSpec("install_loras", "Install or update LoRAs", ["bash", str(SHELL_DIR / "install_loras.sh")]),
    "install_models": ActionSpec("install_models", "Install or update models", ["bash", str(SHELL_DIR / "install_models.sh")]),
    "download_models_civitai": ActionSpec(
        "download_models_civitai",
        "Download models from CivitAI",
        ["bash", str(SHELL_DIR / "install_models.sh")],
        env={"MODEL_SOURCE": "civitai"},
    ),
    "manifest_browser": ActionSpec(
        "manifest_browser", "Browse curated manifests", ["bash", str(SHELL_DIR / "manifest_browser.sh")]
    ),
    "artifact_maintenance": ActionSpec(
        "artifact_maintenance", "Run artifact maintenance", ["bash", str(SHELL_DIR / "artifact_manager.sh")]
    ),
    "self_update": ActionSpec("self_update", "Update installer scripts", ["bash", str(SHELL_DIR / "self_update.sh")]),
    "pull_updates": ActionSpec("pull_updates", "Pull latest Git changes", ["git", "pull"]),
    "launcher_status": ActionSpec(
        "launcher_status", "Show launcher status panel", ["bash", str(LAUNCHER_DIR / "ai_hub_launcher.sh")]
    ),
    "pair_oobabooga": ActionSpec("pair_oobabooga", "Pair LLM + LoRA (oobabooga)", ["bash", str(SHELL_DIR / "pair_oobabooga.sh")]),
    "pair_sillytavern": ActionSpec(
        "pair_sillytavern", "Pair LLM + LoRA (SillyTavern)", ["bash", str(SHELL_DIR / "pair_sillytavern.sh")]
    ),
    "select_lora": ActionSpec("select_lora", "Select a LoRA preset target", ["bash", str(SHELL_DIR / "select_lora.sh")]),
    "save_pairing": ActionSpec(
        "save_pairing", "Save current pairing preset", ["bash", str(SHELL_DIR / "save_pairing_preset.sh")]
    ),
    "load_pairing": ActionSpec(
        "load_pairing", "Load a saved pairing preset", ["bash", str(SHELL_DIR / "load_pairing_preset.sh")]
    ),
    "health_summary": ActionSpec(
        "health_summary", "Run environment health summary", ["bash", str(SHELL_DIR / "health_summary.sh")], env={"HEADLESS": "1"}
    ),
    "web_launcher": ActionSpec(
        "web_launcher", "Start the web launcher UI", python_module=("modules.runtime.web_launcher", [])
    ),
}


def log_line(message: str) -> None:
    timestamp = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    entry = f"{timestamp} {message}\n"
    with LOG_PATH.open("a", encoding="utf-8") as handle:
        handle.write(entry)
    print(entry, end="")


def _check_output(cmd: List[str]) -> str:
    return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True)


def detect_gpu() -> Dict[str, object]:
    label = "Unknown"
    details: List[str] = []
    vram_gb: Optional[int] = None
    driver_hint: Optional[str] = None

    try:
        output = _check_output(["nvidia-smi", "--query-gpu=name,memory.total", "--format=csv,noheader,nounits"])
        rows = [row.strip() for row in output.splitlines() if row.strip()]
        if rows:
            label = "NVIDIA"
            details.extend(rows)
            first_row = rows[0]
            if "," in first_row:
                _, mem = first_row.split(",", 1)
                mem = mem.strip()
            else:
                mem = first_row.split()[-1]
            if mem.isdigit():
                vram_gb = max(1, int(mem) // 1024)
            driver_hint = "NVIDIA drivers detected via nvidia-smi"
    except Exception:
        pass

    if label == "Unknown" and platform.system().lower().startswith("windows"):
        for cmd in (
            ["wmic", "path", "win32_VideoController", "get", "name"],
            [
                "powershell",
                "-NoProfile",
                "-Command",
                "Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name",
            ],
        ):
            try:
                output = _check_output(cmd)
                rows = [row.strip() for row in output.splitlines() if row.strip()]
                if rows:
                    details.extend(rows)
                    lowered = " ".join(rows).lower()
                    if "nvidia" in lowered:
                        label = "NVIDIA"
                    elif "amd" in lowered or "radeon" in lowered:
                        label = "AMD"
                    elif "intel" in lowered:
                        label = "INTEL"
                    driver_hint = "Vendor detected via WMI/CIM"
                    break
            except Exception:
                continue

    wsl_signature = False
    try:
        with open("/proc/version", "r", encoding="utf-8") as handle:
            wsl_signature = "microsoft" in handle.read().lower()
    except FileNotFoundError:
        wsl_signature = False

    directml_supported = platform.system().lower().startswith("windows") or wsl_signature

    if label == "Unknown" and wsl_signature:
        driver_hint = "Fallback to WSL2 GPU passthrough; verify drivers on the Windows host"
    elif label != "Unknown" and wsl_signature:
        driver_hint = driver_hint or "Detected under WSL2; GPU features depend on host drivers"
    elif label != "Unknown" and not driver_hint:
        driver_hint = "Detected via platform defaults"

    return {
        "label": label,
        "details": details,
        "vram_gb": vram_gb,
        "directml": directml_supported,
        "wsl": wsl_signature,
        "driver_hint": driver_hint,
    }


def load_manifests() -> Dict[str, object]:
    manifests: Dict[str, object] = {}
    for name in ("models", "loras"):
        path = MANIFEST_DIR / f"{name}.json"
        if not path.exists():
            manifests[name] = {"items": [], "source": None}
            continue
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
            manifests[name] = {"items": payload.get("items", []), "source": payload.get("source")}
        except json.JSONDecodeError:
            manifests[name] = {"items": [], "source": None}
    return manifests


def list_actions() -> None:
    print("Available actions:")
    for action in ACTION_MAP.values():
        print(f"- {action.id}: {action.description}")


def ensure_bash_available() -> bool:
    try:
        subprocess.check_output(["bash", "--version"], stderr=subprocess.DEVNULL)
        return True
    except Exception:
        return False


def run_action(action_id: str, headless: bool = True) -> int:
    if action_id not in ACTION_MAP:
        raise ValueError(f"Unknown action: {action_id}")

    spec = ACTION_MAP[action_id]
    env = os.environ.copy()
    if headless:
        env["HEADLESS"] = "1"
    env.update(spec.env)
    env.setdefault("AIHUB_LOG_PATH", str(LOG_PATH))
    cwd = PROJECT_ROOT

    if spec.python_module:
        module, extra_args = spec.python_module
        cmd = [sys.executable, "-m", module, *extra_args]
    else:
        if not spec.command:
            raise ValueError(f"Action {action_id} is missing an executable command")
        cmd = spec.command
        if cmd[0] == "git":
            cwd = PROJECT_ROOT
        elif cmd[0] == "bash" and not ensure_bash_available():
            log_line("Bash is not available; please run inside WSL for shell-driven actions.")
            return 1

    log_line(f"Starting action '{action_id}' with command: {' '.join(cmd)}")
    process = subprocess.Popen(cmd, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    assert process.stdout is not None
    with LOG_PATH.open("a", encoding="utf-8") as log_file:
        for line in process.stdout:
            decoded = line.decode(errors="ignore")
            log_file.write(decoded)
            print(decoded, end="")
    return process.wait()


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="AI Hub Windows-friendly launcher")
    parser.add_argument("--action", choices=list(ACTION_MAP.keys()), help="Action id to run from the menu")
    parser.add_argument(
        "--list-actions", action="store_true", help="List available actions and exit"
    )
    parser.add_argument(
        "--manifests", action="store_true", help="Print manifest counts to stdout and exit"
    )
    parser.add_argument(
        "--no-headless", action="store_true", help="Do not force HEADLESS=1 for shell actions"
    )
    parser.add_argument(
        "--detect-gpu", action="store_true", help="Print GPU detection details and exit"
    )
    return parser


def main(argv: Optional[List[str]] = None) -> int:
    parser = build_argument_parser()
    args = parser.parse_args(argv)

    gpu_info = detect_gpu()
    log_line(
        f"Environment summary — GPU: {gpu_info['label']}, DirectML: {gpu_info['directml']}, "
        f"WSL: {gpu_info['wsl']}, VRAM(GB): {gpu_info['vram_gb'] or 'unknown'}, "
        f"Hint: {gpu_info.get('driver_hint') or 'n/a'}"
    )

    if args.detect_gpu:
        print("GPU detection summary:")
        for key, value in gpu_info.items():
            print(f"- {key}: {value}")
        if not gpu_info.get("wsl") and platform.system().lower().startswith("windows"):
            print("Tip: To reuse Linux launchers, run inside WSL2 (Ubuntu recommended) and re-run this probe.")
        return 0

    if args.manifests:
        manifests = load_manifests()
        for name, payload in manifests.items():
            count = len(payload.get("items", []))
            print(f"{name}: {count} entries (source: {payload.get('source')})")
        return 0

    if args.list_actions or not args.action:
        list_actions()
        return 0

    return run_action(args.action, headless=not args.no_headless)


if __name__ == "__main__":
    raise SystemExit(main())
