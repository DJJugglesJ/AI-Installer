import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))

from modules.runtime.hardware.gpu_diagnostics import (  # noqa: E402
    collect_gpu_diagnostics,
    CommandResult,
    SystemInfo,
)


def _runner_factory(responses):
    def _run(command):
        key = " ".join(command)
        value = responses.get(key, "")
        if isinstance(value, tuple):
            stdout, returncode = value
        else:
            stdout, returncode = value, 0 if value else 1
        return CommandResult(stdout=stdout, stderr="", returncode=returncode)

    return _run


def test_collect_gpu_diagnostics_parses_nvidia_smi():
    responses = {
        "nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader,nounits": "NVIDIA RTX 4090,24576,535.54",
    }
    payload = collect_gpu_diagnostics(
        runner=_runner_factory(responses),
        command_exists=lambda cmd: cmd == "nvidia-smi",
        system_info=SystemInfo(platform="Linux", is_wsl=False),
    )

    assert payload["gpus"][0]["name"] == "NVIDIA RTX 4090"
    assert payload["gpus"][0]["memory_mb"] == 24576
    assert payload["gpus"][0]["driver"] == "535.54"
    assert payload["summary"]["backends"]["directml"] is False


def test_collect_gpu_diagnostics_combines_rocm_and_oneapi():
    responses = {
        "rocminfo": "Name: AMD Radeon 7900 XT\nName: AMD Radeon 6600",
        "sycl-ls": "-  level_zero:gpu:0: Intel(R) Arc(TM) A770 Graphics",
        "sycl-ls --version": "sycl-ls version 1.2.3",
    }
    payload = collect_gpu_diagnostics(
        runner=_runner_factory(responses),
        command_exists=lambda cmd: cmd in {"rocminfo", "sycl-ls"},
        system_info=SystemInfo(platform="Linux", is_wsl=True),
    )

    vendors = {gpu["vendor"] for gpu in payload["gpus"]}
    assert vendors == {"AMD", "Intel"}
    backends = payload["summary"]["backends"]
    assert backends["rocm"] is True
    assert backends["oneapi"] is True
    assert backends["directml"] is True


def test_toolkits_and_cuda_versions_reported():
    responses = {
        "nvidia-smi": "NVIDIA-SMI 535.54   Driver Version: 535.54   CUDA Version: 12.2",
        "nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader,nounits": "NVIDIA RTX 4090,24576,535.54",
    }
    payload = collect_gpu_diagnostics(
        runner=_runner_factory(responses),
        command_exists=lambda cmd: cmd == "nvidia-smi",
        system_info=SystemInfo(platform="Linux", is_wsl=False),
    )

    toolkits = payload["summary"]["toolkits"]
    assert toolkits["cuda"]["detected"] is True
    assert toolkits["cuda"]["version"] == "12.2"
    assert payload["summary"]["cpu_fallback"]["expected"] is False


def test_cpu_fallback_schema_when_no_gpu_tools():
    payload = collect_gpu_diagnostics(
        runner=_runner_factory({}),
        command_exists=lambda cmd: False,
        system_info=SystemInfo(platform="Linux", is_wsl=False),
    )

    summary = payload["summary"]
    assert summary["has_gpu"] is False
    assert summary["cpu_fallback"]["expected"] is True
    assert summary["toolkits"]["cuda"]["detected"] is False
