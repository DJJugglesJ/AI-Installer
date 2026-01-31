from pathlib import Path
import sys

sys.path.append(str(Path(__file__).resolve().parents[2]))

from modules.runtime.web_launcher import server  # noqa: E402


def _api(tmp_path: Path) -> server.WebLauncherAPI:
    project_root = tmp_path / "project"
    (project_root / "modules").mkdir(parents=True, exist_ok=True)
    (project_root / "manifests").mkdir(parents=True, exist_ok=True)
    return server.WebLauncherAPI(project_root=project_root, config_path=tmp_path / "config.yaml")


def test_prompt_feedback_applies_scene_updates(tmp_path: Path) -> None:
    api = _api(tmp_path)
    scene = {"world": "castle", "extra_elements": ["fog"]}
    result = api.apply_feedback(scene, "mood: eerie; add elements: moonlight")

    updated = result["scene"]
    assert updated["world"] == "castle"
    assert updated["mood"] == "eerie"
    assert "moonlight" in updated["extra_elements"]


def test_batch_tag_images_returns_payload(tmp_path: Path) -> None:
    api = _api(tmp_path)
    payload = {
        "card": {
            "id": "hera",
            "name": "Hera",
            "nsfw_allowed": False,
            "anatomy_tags": ["android"],
            "trigger_token": "hera_tok",
            "trigger_tokens": ["hera_tok"],
            "wardrobe": ["jacket"],
            "reference_images": [],
            "metadata": {},
        },
        "image_contexts": [
            {"image_path": "dataset/one.png", "extra_tags": ["portrait"], "caption": "soft lighting"}
        ],
    }

    result = api.batch_tag_images(payload)

    assert result["metadata"]["character_id"] == "hera"
    assert result["metadata"]["count"] == 1
    assert "dataset/one.png" in result["tags_by_image"]
