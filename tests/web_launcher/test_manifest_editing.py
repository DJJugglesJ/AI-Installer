from pathlib import Path
import json
import sys

sys.path.append(str(Path(__file__).resolve().parents[2]))

from modules.runtime.web_launcher import server  # noqa: E402


def _write_manifest(path: Path, name: str, item: dict) -> None:
    payload = {"source": "unit-test", "items": [item]}
    (path / f"{name}.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _api(tmp_path: Path) -> server.WebLauncherAPI:
    project_root = tmp_path / "project"
    manifests_dir = project_root / "manifests"
    manifests_dir.mkdir(parents=True)
    _write_manifest(
        manifests_dir,
        "models",
        {
            "name": "Sample Model",
            "version": "1.0",
            "filename": "sample.safetensors",
            "url": "https://example.com/sample",
            "size_bytes": 123,
            "checksum": "old",
            "license": "MIT",
            "training_data": "Unknown",
            "recommended_precision": "fp16",
            "tags": ["baseline"],
            "notes": "",
        },
    )
    _write_manifest(
        manifests_dir,
        "loras",
        {
            "name": "Sample LoRA",
            "version": "0.1",
            "filename": "sample-lora.safetensors",
            "url": "https://example.com/lora",
            "size_bytes": 456,
            "checksum": "old-lora",
            "license": "MIT",
            "training_data": "Unknown",
            "recommended_precision": "fp16",
            "tags": ["starter"],
            "notes": "",
        },
    )
    return server.WebLauncherAPI(project_root=project_root, config_path=tmp_path / "config.yaml")


def test_manifest_update_round_trip(tmp_path: Path) -> None:
    api = _api(tmp_path)
    result = api.update_manifest_item(
        "models",
        "sample-model",
        {
            "tags": ["updated"],
            "checksum": "new",
            "metadata": {"origin": "unit-test"},
            "license": "Apache-2.0",
            "training_data": "Community curated",
            "recommended_precision": "bf16",
        },
    )

    assert result["item"]["tags"] == ["updated"]
    assert result["item"]["checksum"] == "new"
    assert result["item"]["metadata"] == {"origin": "unit-test"}
    assert result["item"]["license"] == "Apache-2.0"
    assert result["item"]["training_data"] == "Community curated"
    assert result["item"]["recommended_precision"] == "bf16"
    assert result["has_errors"] is False

    manifest_path = api.manifest_dir / "models.json"
    stored = json.loads(manifest_path.read_text(encoding="utf-8"))
    stored_item = stored["items"][0]
    assert stored_item["tags"] == ["updated"]
    assert stored_item["checksum"] == "new"
    assert stored_item["metadata"] == {"origin": "unit-test"}
    assert stored_item["license"] == "Apache-2.0"
    assert stored_item["training_data"] == "Community curated"
    assert stored_item["recommended_precision"] == "bf16"
    assert "health" not in stored_item


def test_manifest_validation_reports_ok(tmp_path: Path) -> None:
    api = _api(tmp_path)
    validation = api.validate_manifest("models")

    assert validation["has_errors"] is False
    assert validation["errors"] == []


def test_manifest_update_rejects_bad_payload(tmp_path: Path) -> None:
    api = _api(tmp_path)

    try:
        api.update_manifest_item("models", "sample-model", {"tags": "bad"})
    except ValueError as exc:
        assert "tags" in str(exc)
    else:  # pragma: no cover - defensive
        raise AssertionError("Expected manifest update schema validation to fail")


def test_manifest_update_rejects_unknown_fields(tmp_path: Path) -> None:
    api = _api(tmp_path)

    try:
        api.update_manifest_item("models", "sample-model", {"unexpected": "value"})
    except ValueError as exc:
        assert "Unexpected field" in str(exc)
    else:  # pragma: no cover - defensive
        raise AssertionError("Expected manifest update schema validation to fail")
