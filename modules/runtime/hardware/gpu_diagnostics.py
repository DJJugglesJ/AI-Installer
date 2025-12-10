"""Cross-platform GPU diagnostics surfaced to CLI and the web launcher.

The helper is intentionally defensive: it only attempts commands that are
present on the host and returns structured data with backend hints rather than
failing when a given tool is unavailable.
"""
from __future__ import annotations

import json
import platform
import re
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Callable, Dict, Iterable, List, Optional, Tuple


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


def _parse_version_from_output(patterns: Tuple[str, ...], stdout: str) -> Optional[str]:
    for line in stdout.splitlines():
        for pattern in patterns:
            match = re.search(pattern, line, re.IGNORECASE)
            if match:
                return match.group(1)
    return None


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


def _detect_toolkits(
    *, runner: CommandRunner, command_exists: CommandExists, system_info: SystemInfo
) -> Dict[str, Dict[str, object]]:
    toolkits: Dict[str, Dict[str, object]] = {
        "cuda": {"detected": False, "version": None, "notes": []},
        "rocm": {"detected": False, "version": None, "notes": []},
        "oneapi": {"detected": False, "version": None, "notes": []},
        "directml": {
            "detected": system_info.platform in {"Windows", "Darwin"} or system_info.is_wsl,
            "version": None,
            "notes": [],
        },
    }

    if command_exists("nvidia-smi"):
        toolkits["cuda"]["detected"] = True
        smi_output = runner(["nvidia-smi"])
        if smi_output.stdout:
            version = _parse_version_from_output((r"CUDA Version:\s*([0-9.]+)",), smi_output.stdout)
            if version:
                toolkits["cuda"]["version"] = version
        elif smi_output.returncode != 0:
            toolkits["cuda"]["notes"].append("nvidia-smi reported an error while probing CUDA version.")

    if command_exists("rocminfo"):
        toolkits["rocm"]["detected"] = True
        rocminfo_result = runner(["rocminfo"])
        if rocminfo_result.stdout:
            version = _parse_version_from_output((r"ROCm version:\s*([0-9.]+)", r"ROCm.*?([0-9]+\.[0-9.]+)"), rocminfo_result.stdout)
            if version:
                toolkits["rocm"]["version"] = version
        elif rocminfo_result.returncode != 0:
            toolkits["rocm"]["notes"].append("rocminfo failed to return ROCm descriptors.")

    if command_exists("sycl-ls"):
        toolkits["oneapi"]["detected"] = True
        sycl_version = runner(["sycl-ls", "--version"])
        if sycl_version.stdout:
            version = _parse_version_from_output((r"sycl-ls\s*version\s*([0-9.]+)", r"version\s*([0-9.]+)"), sycl_version.stdout)
            if version:
                toolkits["oneapi"]["version"] = version
        elif sycl_version.returncode != 0:
            toolkits["oneapi"]["notes"].append("sycl-ls --version did not provide version details.")

    return toolkits


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

    toolkits = _detect_toolkits(runner=runner, command_exists=command_exists, system_info=system_info)

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

    cpu_fallback = {
        "expected": not devices,
        "reason": "No GPUs reported by diagnostics tooling; CPU runtimes will be used by default." if not devices else "GPU detected; CPU fallback should be optional only.",
    }

    if not devices:
        notes.append("No GPUs detected. Ensure drivers or runtimes are installed if acceleration is expected.")

    summary = {
        "has_gpu": bool(devices),
        "platform": system_info.platform,
        "is_wsl": system_info.is_wsl,
        "backends": backends,
        "toolkits": toolkits,
        "notes": notes,
        "cpu_fallback": cpu_fallback,
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
    toolkits = summary.get("toolkits", {})
    if toolkits:
        toolkit_lines = []
        for name, meta in toolkits.items():
            if not isinstance(meta, dict):
                continue
            detected = meta.get("detected", False)
            version = meta.get("version")
            detail = f"{name}: {'present' if detected else 'missing'}"
            if version:
                detail += f" (v{version})"
            toolkit_lines.append(detail)
        if toolkit_lines:
            lines.append("Toolkits → " + " | ".join(toolkit_lines))
    cpu_fallback = summary.get("cpu_fallback", {})
    if cpu_fallback:
        expected = cpu_fallback.get("expected")
        reason = cpu_fallback.get("reason") or ""
        lines.append(f"CPU fallback expected: {expected} — {reason}")
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
