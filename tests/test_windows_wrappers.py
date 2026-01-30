from __future__ import annotations

import re
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
LAUNCHER_DIR = PROJECT_ROOT / "launcher"

WRAPPER_ACTIONS = [
    "install_webui",
    "install_kobold",
    "install_sillytavern",
    "install_models",
    "install_loras",
    "self_update",
    "pull_updates",
    "run_webui",
    "run_kobold",
    "run_sillytavern",
    "run_asr",
    "run_tts",
    "run_txt2vid",
    "run_img2vid",
    "performance_flags",
    "manifest_browser",
    "artifact_maintenance",
    "health_summary",
    "launcher_status",
]


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_windows_wrappers_present_and_linked() -> None:
    sys.path.insert(0, str(PROJECT_ROOT))
    from launcher import aihub_menu  # pylint: disable=import-error

    missing = []
    for action in WRAPPER_ACTIONS:
        ps1_path = LAUNCHER_DIR / f"{action}.ps1"
        bat_path = LAUNCHER_DIR / f"{action}.bat"
        if not ps1_path.exists():
            missing.append(str(ps1_path))
        if not bat_path.exists():
            missing.append(str(bat_path))

        ps1_contents = _read(ps1_path)
        bat_contents = _read(bat_path)

        assert re.search(rf"--action',\s*'{action}'", ps1_contents)
        assert re.search(rf"--action {action}(\s|$)", bat_contents)

        assert action in aihub_menu.ACTION_MAP
        spec = aihub_menu.ACTION_MAP[action]
        for token in spec.command:
            if token.endswith((".sh", ".ps1")):
                assert Path(token).exists()

    assert not missing, f"Missing wrapper files: {missing}"
