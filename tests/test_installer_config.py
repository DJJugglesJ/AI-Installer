import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG_SERVICE = ROOT / "modules" / "config_service" / "config_service.py"
SCHEMA = ROOT / "modules" / "config_service" / "installer_schema.yaml"
PROFILE = ROOT / "modules" / "config_service" / "profiles" / "ci-basic.yaml"


def run_cmd(args, cwd=None, env=None):
    return subprocess.run(
        args,
        cwd=cwd or ROOT,
        env=env,
        capture_output=True,
        text=True,
    )


def test_profile_outputs_json():
    result = run_cmd(
        [
            sys.executable,
            str(CONFIG_SERVICE),
            "installer-profile",
            "--schema",
            str(SCHEMA),
            "--profile",
            "ci-basic",
            "--format",
            "json",
        ]
    )
    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert payload["gpu_mode"] == "cpu"
    assert payload["install_target"] == "webui"
    assert payload["enable_low_vram"] is True


def test_invalid_gpu_mode_is_rejected(tmp_path):
    bad_config = tmp_path / "bad.conf"
    bad_config.write_text("gpu_mode=invalid\n")

    result = run_cmd(
        [
            sys.executable,
            str(CONFIG_SERVICE),
            "installer-profile",
            "--schema",
            str(SCHEMA),
            "--file",
            str(bad_config),
        ]
    )
    assert result.returncode == 1
    assert "gpu_mode" in result.stderr


def test_install_script_creates_backups_and_applies_headless(tmp_path):
    env = {
        "HOME": str(tmp_path),
        "CONFIG_STATE_FILE": str(tmp_path / "config.json"),
        "CONFIG_FILE": str(tmp_path / "installer.conf"),
        "LOG_FILE": str(tmp_path / "install.log"),
        "AIHUB_SKIP_INSTALL_STEPS": "1",
    }

    env["PATH"] = f"{env['HOME']}:{Path('/usr/bin')}"  # ensure sudo path is visible

    state_file = Path(env["CONFIG_STATE_FILE"])
    state_file.write_text("{\n  \"version\": 2\n}\n")

    result = run_cmd(
        ["bash", str(ROOT / "install.sh"), "--headless", "--profile", "ci-basic"],
        env=env,
    )
    assert result.returncode == 0, result.stderr

    backups = list(tmp_path.glob("config.json.*.bak"))
    assert backups, "Expected a timestamped config backup"

    updated = json.loads(state_file.read_text())
    assert updated.get("gpu", {}).get("mode") == "cpu"
    assert updated.get("installer", {}).get("install_target") == "webui"
