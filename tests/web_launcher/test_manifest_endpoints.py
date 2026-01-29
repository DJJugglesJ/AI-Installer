import hashlib
import json
from pathlib import Path
import sys

sys.path.append(str(Path(__file__).resolve().parents[2]))

from modules.runtime.manifests import helpers as manifest_helpers  # noqa: E402
from modules.runtime.web_launcher import server  # noqa: E402


def _write_manifest(manifest_dir: Path, models: list, loras: list) -> None:
    manifest_dir.mkdir(parents=True, exist_ok=True)
    (manifest_dir / "models.json").write_text(
        json.dumps({"source": "test", "items": models}, indent=2), encoding="utf-8"
    )
    (manifest_dir / "loras.json").write_text(
        json.dumps({"source": "test", "items": loras}, indent=2), encoding="utf-8"
    )


def _sha256_for_text(content: str) -> str:
    return hashlib.sha256(content.encode("utf-8")).hexdigest().upper()


def _api(tmp_path: Path, manifest_dir: Path) -> server.WebLauncherAPI:
    project_root = Path(__file__).resolve().parents[2]
    return server.WebLauncherAPI(
        project_root=project_root,
        config_path=tmp_path / "config.yaml",
        history_path=tmp_path / "history.json",
        manifest_dir=manifest_dir,
    )


def test_manifest_list_includes_checksum_status(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    models_dir = tmp_path / "ai-hub" / "models"
    models_dir.mkdir(parents=True, exist_ok=True)
    model_name = "Test Model"
    filename = "test-model.safetensors"
    file_path = models_dir / filename
    file_path.write_text("hello world", encoding="utf-8")
    checksum = _sha256_for_text("hello world")

    manifest_dir = tmp_path / "manifests"
    _write_manifest(
        manifest_dir,
        models=[
            {
                "name": model_name,
                "filename": filename,
                "checksum": checksum,
                "tags": ["test"],
                "notes": "notes",
            }
        ],
        loras=[],
    )

    api = _api(tmp_path, manifest_dir)
    manifest = api.list_manifest("models")
    assert manifest["items"][0]["checksum_status"] == "unchecked"
    assert manifest["items"][0]["tags"] == ["test"]


def test_manifest_validation_marks_verified(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    models_dir = tmp_path / "ai-hub" / "models"
    models_dir.mkdir(parents=True, exist_ok=True)
    filename = "test-model.safetensors"
    file_path = models_dir / filename
    file_path.write_text("validate me", encoding="utf-8")
    checksum = _sha256_for_text("validate me")

    manifest_dir = tmp_path / "manifests"
    _write_manifest(
        manifest_dir,
        models=[{"name": "Validation Model", "filename": filename, "checksum": checksum}],
        loras=[],
    )

    api = _api(tmp_path, manifest_dir)
    payload = api.validate_manifest_checksums("models")
    items = payload["items"]["models"]
    assert items[0]["checksum_status"] == "verified"
    assert payload["summary"]["models"]["verified"] == 1


def test_manifest_update_persists_metadata(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    manifest_dir = tmp_path / "manifests"
    model_name = "Metadata Model"
    _write_manifest(
        manifest_dir,
        models=[{"name": model_name, "filename": "meta.safetensors", "tags": ["old"], "notes": "old notes"}],
        loras=[],
    )

    api = _api(tmp_path, manifest_dir)
    slug = manifest_helpers.slugify(model_name)
    updated = api.update_manifest_item("models", slug, {"tags": ["new", "tag"], "notes": "updated notes"})

    stored = json.loads((manifest_dir / "models.json").read_text(encoding="utf-8"))
    stored_item = stored["items"][0]

    assert updated["item"]["tags"] == ["new", "tag"]
    assert updated["item"]["notes"] == "updated notes"
    assert stored_item["tags"] == ["new", "tag"]
    assert stored_item["notes"] == "updated notes"
