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
        stdout = responses.get(key, "")
        return CommandResult(stdout=stdout, stderr="", returncode=0 if stdout else 1)

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
