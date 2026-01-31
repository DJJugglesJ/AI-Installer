import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[4]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from modules.runtime.character_studio import models as character_models
from modules.runtime.character_studio.models import CharacterCard
from modules.runtime.prompt_builder import __main__ as prompt_cli


@pytest.fixture(autouse=True)
def patch_card_storage(tmp_path, monkeypatch):
    monkeypatch.setattr(character_models, "CARD_STORAGE_ROOT", tmp_path)
    return tmp_path


def test_cli_compiles_scene(tmp_path, capsys):
    card = CharacterCard(
        id="mage",
        name="Mage",
        nsfw_allowed=True,
        default_prompt_snippet="arcane runes",
        trigger_token="magetoken",
        anatomy_tags=["robes"],
    )
    card.save(path=tmp_path / "mage" / "card.json")

    scene_payload = {
        "world": "fantasy",
        "setting": "library",
        "mood": "mysterious",
        "characters": [
            {"slot_id": "caster", "character_id": "mage", "role": "support"}
        ],
        "extra_elements": ["floating candles"],
    }
    scene_path = tmp_path / "scene.json"
    scene_path.write_text(json.dumps(scene_payload), encoding="utf-8")

    prompt_cli.main(["--scene", str(scene_path), "--feedback", "add elements: magic circle"])
    output = capsys.readouterr().out
    payload = json.loads(output)

    assert payload["error"] is None
    assert payload["metadata"] == {}
    assert payload["data"]["positive_prompt"]
    assert any("magetoken" in part for part in payload["data"]["positive_prompt"])
    assert any("magic circle" in part for part in payload["data"]["positive_prompt"])
    assert payload["data"]["lora_calls"] == []


def test_cli_feedback_only_returns_scene(tmp_path, capsys):
    scene_payload = {
        "world": "fantasy",
        "setting": "tower",
        "mood": "calm",
        "characters": [],
        "extra_elements": ["moonlight"],
    }
    scene_path = tmp_path / "scene.json"
    scene_path.write_text(json.dumps(scene_payload), encoding="utf-8")

    prompt_cli.main(
        [
            "--scene",
            str(scene_path),
            "--feedback",
            "mood: tense; add elements: mist",
            "--feedback-only",
        ]
    )
    output = capsys.readouterr().out
    payload = json.loads(output)

    assert payload["error"] is None
    assert payload["metadata"] == {}
    assert payload["data"]["mood"] == "tense"
    assert "mist" in payload["data"]["extra_elements"]


def test_cli_feedback_only_requires_feedback(tmp_path, capsys):
    scene_payload = {
        "world": "fantasy",
        "setting": "tower",
        "mood": "calm",
        "characters": [],
        "extra_elements": ["moonlight"],
    }
    scene_path = tmp_path / "scene.json"
    scene_path.write_text(json.dumps(scene_payload), encoding="utf-8")

    with pytest.raises(SystemExit):
        prompt_cli.main(["--scene", str(scene_path), "--feedback-only"])
    output = capsys.readouterr().out
    payload = json.loads(output)

    assert payload["data"] is None
    assert payload["metadata"] == {}
    assert payload["error"]["message"] == "feedback is required when using --feedback-only"
