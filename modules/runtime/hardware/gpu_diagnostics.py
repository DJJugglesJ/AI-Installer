"""Cross-platform GPU diagnostics surfaced to CLI and the web launcher.

The helper is intentionally defensive: it only attempts commands that are
present on the host and returns structured data with backend hints rather than
failing when a given tool is unavailable.
"""
from __future__ import annotations

import json
import platform
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Callable, Dict, Iterable, List, Optional


@dataclass
class CommandResult:
    """Simple command result used for dependency injection in tests."""

    stdout: str = ""
    stderr: str = ""
    returncode: int = 0


CommandRunner = Callable[[List[str]], CommandResult]
CommandExists = Callable[[str], bool]


@dataclass
class GPUBackendHints:
    rocm: bool = False
    oneapi: bool = False
    directml: bool = False
    notes: List[str] = field(default_factory=list)


@dataclass
class GPUDevice:
    vendor: str
    name: str
    memory_mb: Optional[int] = None
    driver: Optional[str] = None
    backend_hints: GPUBackendHints = field(default_factory=GPUBackendHints)
    warnings: List[str] = field(default_factory=list)


@dataclass
class SystemInfo:
    platform: str
    is_wsl: bool = False


def _default_runner(command: List[str]) -> CommandResult:
    try:
        completed = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
        )
        return CommandResult(stdout=completed.stdout, stderr=completed.stderr, returncode=completed.returncode)
    except FileNotFoundError:
        return CommandResult(stdout="", stderr="command not found", returncode=127)


def _command_exists(command: str) -> bool:
    return shutil.which(command) is not None


def _detect_system_info() -> SystemInfo:
    system = platform.system()
    is_wsl = False
    if system == "Linux":
        try:
            version = Path("/proc/version").read_text(encoding="utf-8")
            is_wsl = "microsoft" in version.lower()
        except OSError:
            is_wsl = False
    return SystemInfo(platform=system, is_wsl=is_wsl)


def _parse_int(value: str) -> Optional[int]:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _parse_nvidia_smi(stdout: str, system_info: SystemInfo) -> List[GPUDevice]:
    devices: List[GPUDevice] = []
    for line in stdout.splitlines():
        if not line.strip():
            continue
        parts = [part.strip() for part in line.split(",")]
        name = parts[0] if parts else "NVIDIA GPU"
        memory_mb = _parse_int(parts[1]) if len(parts) > 1 else None
        driver = parts[2] if len(parts) > 2 else None
        devices.append(
            GPUDevice(
                vendor="NVIDIA",
                name=name,
                memory_mb=memory_mb,
                driver=driver,
                backend_hints=GPUBackendHints(
                    rocm=False,
                    oneapi=False,
                    directml=system_info.platform in {"Windows", "Darwin"} or system_info.is_wsl,
                    notes=[],
                ),
                warnings=[] if driver else ["Driver not reported by nvidia-smi"],
            )
        )
    return devices


def _parse_rocminfo(stdout: str, system_info: SystemInfo) -> List[GPUDevice]:
    names: List[str] = []
    for line in stdout.splitlines():
        line = line.strip()
        if line.startswith("Name:"):
            parts = line.split(":", 1)
            if len(parts) == 2:
                candidate = parts[1].strip()
                if candidate and candidate not in names:
                    names.append(candidate)
    if not names:
        return []

    return [
        GPUDevice(
            vendor="AMD",
            name=name,
            memory_mb=None,
            driver=None,
            backend_hints=GPUBackendHints(
                rocm=True,
                oneapi=False,
                directml=system_info.is_wsl,
                notes=["ROCm tooling detected; enable HIP/ROCm flags where supported."],
            ),
            warnings=[],
        )
        for name in names
    ]


def _parse_sycl_ls(stdout: str, system_info: SystemInfo) -> List[GPUDevice]:
    devices: List[GPUDevice] = []
    for line in stdout.splitlines():
        if "level_zero:gpu" not in line and "opencl:gpu" not in line:
            continue
        cleaned = line.strip().lstrip("-").strip()
        parts = cleaned.split(":")
        # Expected: level_zero:gpu:0: Intel(R) Arc(TM) A770 Graphics
        name = parts[-1].strip() if parts else "GPU"
        devices.append(
            GPUDevice(
                vendor="Intel" if "Intel" in name else "Unknown",
                name=name,
                backend_hints=GPUBackendHints(
                    rocm=False,
                    oneapi=True,
                    directml=system_info.is_wsl or system_info.platform == "Windows",
                    notes=["oneAPI Level Zero runtime detected via sycl-ls."],
                ),
            )
        )
    return devices


def collect_gpu_diagnostics(
    *,
    runner: CommandRunner | None = None,
    command_exists: CommandExists | None = None,
    system_info: SystemInfo | None = None,
) -> Dict[str, object]:
    """Gather GPU inventory and backend hints using available tooling."""

    command_exists = command_exists or _command_exists
    runner = runner or _default_runner
    system_info = system_info or _detect_system_info()

    devices: List[GPUDevice] = []
    notes: List[str] = []

    if command_exists("nvidia-smi"):
        result = runner(["nvidia-smi", "--query-gpu=name,memory.total,driver_version", "--format=csv,noheader,nounits"])
        if result.returncode == 0 and result.stdout:
            devices.extend(_parse_nvidia_smi(result.stdout, system_info))
        else:
            notes.append("nvidia-smi is present but did not return usable output.")

    if command_exists("rocminfo"):
        rocminfo_result = runner(["rocminfo"])
        if rocminfo_result.returncode == 0 and rocminfo_result.stdout:
            devices.extend(_parse_rocminfo(rocminfo_result.stdout, system_info))
        else:
            notes.append("rocminfo is installed but failed to return GPU descriptors.")

    if command_exists("sycl-ls"):
        sycl_result = runner(["sycl-ls"])
        if sycl_result.returncode == 0 and sycl_result.stdout:
            devices.extend(_parse_sycl_ls(sycl_result.stdout, system_info))
        else:
            notes.append("sycl-ls is installed but did not enumerate devices.")

    backends = {
        "rocm": any(device.backend_hints.rocm for device in devices) or command_exists("rocminfo"),
        "oneapi": any(device.backend_hints.oneapi for device in devices) or command_exists("sycl-ls"),
        "directml": any(device.backend_hints.directml for device in devices)
        or system_info.platform == "Windows"
        or system_info.is_wsl,
    }

    summary = {
        "has_gpu": bool(devices),
        "platform": system_info.platform,
        "is_wsl": system_info.is_wsl,
        "backends": backends,
        "notes": notes,
    }

    return {
        "gpus": [asdict(device) for device in devices],
        "summary": summary,
    }


def format_summary(payload: Dict[str, object]) -> str:
    summary = payload.get("summary", {}) if isinstance(payload, dict) else {}
    gpus = payload.get("gpus", []) if isinstance(payload, dict) else []
    lines = []
    lines.append("GPU Diagnostics")
    lines.append("----------------")
    lines.append(f"Platform: {summary.get('platform', 'unknown')} (WSL: {summary.get('is_wsl', False)})")
    backend = summary.get("backends", {})
    lines.append(
        "Backends → "
        f"ROCm: {backend.get('rocm', False)} | oneAPI: {backend.get('oneapi', False)} | DirectML: {backend.get('directml', False)}"
    )
    if not gpus:
        lines.append("No GPUs detected by available diagnostics tools.")
        return "\n".join(lines)
    for idx, device in enumerate(gpus, start=1):
        name = device.get("name", "GPU")
        vendor = device.get("vendor", "")
        memory = device.get("memory_mb")
        driver = device.get("driver")
        mem_note = f" • VRAM: {memory} MB" if memory is not None else ""
        driver_note = f" • Driver: {driver}" if driver else ""
        lines.append(f"[{idx}] {vendor} {name}{mem_note}{driver_note}")
    if summary.get("notes"):
        lines.append("")
        lines.extend(summary["notes"])
    return "\n".join(lines)


def main(argv: Optional[Iterable[str]] = None) -> None:
    payload = collect_gpu_diagnostics()
    print(json.dumps(payload, indent=2))
    print()
    print(format_summary(payload))


if __name__ == "__main__":
    main(sys.argv[1:])
