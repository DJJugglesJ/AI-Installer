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

from modules.path_utils import (
    ensure_file_path,
    get_config_file,
    get_config_root,
    get_log_path,
    get_state_path,
)

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SHELL_DIR = PROJECT_ROOT / "modules" / "shell"
WINDOWS_SHELL_DIR = PROJECT_ROOT / "launcher" / "windows"
LAUNCHER_DIR = PROJECT_ROOT / "launcher"
MANIFEST_DIR = PROJECT_ROOT / "manifests"
IS_WINDOWS = platform.system().lower().startswith("windows")
LOG_PATH = ensure_file_path(get_log_path())
os.environ.setdefault("AIHUB_LOG_PATH", str(LOG_PATH))
os.environ.setdefault("AIHUB_CONFIG_DIR", str(get_config_root()))
os.environ.setdefault("CONFIG_FILE", str(get_config_file()))
os.environ.setdefault("CONFIG_STATE_FILE", str(get_state_path()))


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


def _shell_command(script_base: str) -> List[str]:
    script_name = script_base if script_base.endswith(".sh") else f"{script_base}.sh"
    if IS_WINDOWS:
        ps_path = WINDOWS_SHELL_DIR / f"{Path(script_name).stem}.ps1"
        return [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(ps_path),
        ]
    return ["bash", str(SHELL_DIR / script_name)]


ACTION_MAP: Dict[str, ActionSpec] = {
    "run_webui": ActionSpec(
        "run_webui",
        "Launch Stable Diffusion WebUI from the default workspace",
        _shell_command("run_webui"),
    ),
    "performance_flags": ActionSpec(
        "performance_flags",
        "Review FP16/xFormers/DirectML toggles",
        _shell_command("performance_flags"),
    ),
    "run_kobold": ActionSpec("run_kobold", "Launch KoboldAI", _shell_command("run_kobold")),
    "run_sillytavern": ActionSpec(
        "run_sillytavern", "Launch SillyTavern", _shell_command("run_sillytavern")
    ),
    "install_loras": ActionSpec(
        "install_loras",
        "Install or refresh LoRAs into ~/AI/LoRAs",
        _shell_command("install_loras"),
    ),
    "install_models": ActionSpec(
        "install_models",
        "Install or update models into ~/ai-hub/models",
        _shell_command("install_models"),
    ),
    "download_models_civitai": ActionSpec(
        "download_models_civitai",
        "Download models from CivitAI into ~/ai-hub/models",
        _shell_command("install_models"),
        env={"MODEL_SOURCE": "civitai"},
    ),
    "manifest_browser": ActionSpec(
        "manifest_browser", "Browse curated manifests", _shell_command("manifest_browser")
    ),
    "artifact_maintenance": ActionSpec(
        "artifact_maintenance",
        "Run artifact maintenance",
        _shell_command("artifact_manager"),
    ),
    "self_update": ActionSpec("self_update", "Self-update bundled installer scripts", _shell_command("self_update")),
    "pull_updates": ActionSpec("pull_updates", "Git pull for cloned checkouts", ["git", "pull"]),
    "launcher_status": ActionSpec(
        "launcher_status", "Show launcher status panel", ["bash", str(LAUNCHER_DIR / "ai_hub_launcher.sh")]
    ),
    "pair_oobabooga": ActionSpec(
        "pair_oobabooga", "Pair an oobabooga model with a LoRA", _shell_command("pair_oobabooga")
    ),
    "pair_sillytavern": ActionSpec(
        "pair_sillytavern", "Pick backend + model for SillyTavern", _shell_command("pair_sillytavern")
    ),
    "select_lora": ActionSpec("select_lora", "Choose a LoRA preset target", _shell_command("select_lora")),
    "save_pairing": ActionSpec(
        "save_pairing", "Save the current pairing preset", _shell_command("save_pairing_preset")
    ),
    "load_pairing": ActionSpec(
        "load_pairing", "Load a saved pairing preset", _shell_command("load_pairing_preset")
    ),
    "health_summary": ActionSpec(
        "health_summary",
        "Run environment health summary",
        _shell_command("health_summary"),
        env={"HEADLESS": "1"},
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
    hardware: List[str] = []
    modules: List[str] = []
    vram_gb: Optional[int] = None
    driver_hint: Optional[str] = None
    guidance: Optional[str] = None

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

    if platform.system().lower() == "linux":
        try:
            hardware_output = _check_output(["bash", "-lc", "lspci | grep -Ei 'VGA|3D|Display'"])
            hardware = [line.strip() for line in hardware_output.splitlines() if line.strip()]
        except Exception:
            hardware = []

        try:
            stack_output = _check_output(
                ["bash", "-lc", "lspci -nnk | grep -Ei 'VGA|3D|Display' -A3"]
            )
            extra_lines = [line.strip() for line in stack_output.splitlines() if line.strip()]
            hardware.extend([line for line in extra_lines if line not in hardware])
        except Exception:
            pass

        try:
            module_output = _check_output(["bash", "-lc", "lsmod | awk '{print $1}' | grep -E 'nvidia|amdgpu|i915'"])
            modules = [line.strip() for line in module_output.splitlines() if line.strip()]
        except Exception:
            modules = []

    if label == "AMD":
        guidance = (
            "AMD GPU detected. Validate against the ROCm support matrix, install mesa-vulkan-drivers, "
            "and confirm HIP/OpenCL availability with rocminfo/clinfo before enabling ROCm toggles."
        )
        if wsl_signature:
            guidance += " DirectML can be used from Windows/WSL when ROCm is unavailable."
    elif label == "INTEL":
        guidance = (
            "Intel GPU detected. Install intel-opencl-icd or Level Zero/oneAPI runtimes and enable "
            "OpenVINO or DirectML flags when available to avoid CPU-only fallback."
        )
        if wsl_signature:
            guidance += " WSL2 users should keep Windows GPU drivers current for passthrough."

    return {
        "label": label,
        "details": details,
        "hardware": hardware,
        "modules": modules,
        "vram_gb": vram_gb,
        "directml": directml_supported,
        "wsl": wsl_signature,
        "driver_hint": driver_hint,
        "guidance": guidance,
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
    log_file_handle = LOG_PATH.open("a", encoding="utf-8")
    try:
        for line in process.stdout:
            decoded = line.decode(errors="ignore")
            if log_file_handle:
                log_file_handle.write(decoded)
            print(decoded, end="")
    finally:
        if log_file_handle:
            log_file_handle.close()
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
        f"Hint: {gpu_info.get('driver_hint') or 'n/a'}, Guidance: {gpu_info.get('guidance') or 'n/a'}"
    )

    if args.detect_gpu:
        print("GPU detection summary:")
        for key, value in gpu_info.items():
            print(f"- {key}: {value}")
        if gpu_info.get("hardware"):
            print("Hardware enumeration (lspci / vendor APIs):")
            for line in gpu_info["hardware"]:
                print(f"  - {line}")
        if gpu_info.get("modules"):
            print("Kernel modules detected:")
            for mod in gpu_info["modules"]:
                print(f"  - {mod}")
        if gpu_info.get("guidance"):
            print(f"Guidance: {gpu_info['guidance']}")
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
