from pathlib import Path
import sys

sys.path.append(str(Path(__file__).resolve().parents[2]))

from modules.config_service import config_service  # noqa: E402
from modules.runtime.web_launcher import server  # noqa: E402


def _api(tmp_path: Path) -> server.WebLauncherAPI:
    project_root = Path(__file__).resolve().parents[2]
    return server.WebLauncherAPI(project_root=project_root, config_path=tmp_path / "config.yaml")


def test_manifest_detail_round_trip(tmp_path):
    api = _api(tmp_path)
    manifest = api.list_manifest("models")
    first = manifest["items"][0]
    detail = api.get_manifest_item("models", first.get("slug") or first["name"])

    assert detail["item"]["name"] == first["name"]
    assert "health" in detail["item"]


def test_pairing_persists_to_config(tmp_path):
    api = _api(tmp_path)
    model_name = api.list_manifest("models")["items"][0]["name"]
    lora_name = api.list_manifest("loras")["items"][0]["name"]

    result = api.update_pairings({"model": model_name, "loras": [lora_name]})
    loaded = config_service.load_config(str(tmp_path / "config.yaml"), env_prefix="", overrides=[])

    assert result["selection"]["model"] == model_name
    assert result["selection"]["loras"] == [lora_name]
    assert loaded.data["selection"]["model"] == model_name


def test_pairing_validation_rejects_unknown(tmp_path):
    api = _api(tmp_path)

    try:
        api.update_pairings({"model": "missing", "loras": ["also-missing"]})
    except ValueError as exc:
        assert "Unknown model" in str(exc) or "Unknown LoRA" in str(exc)
    else:  # pragma: no cover - defensive
        raise AssertionError("Expected validation error for unknown manifest entries")
