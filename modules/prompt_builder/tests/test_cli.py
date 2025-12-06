import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from modules.character_studio import models as character_models
from modules.character_studio.models import CharacterCard
from modules.prompt_builder import __main__ as prompt_cli


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

    assert payload["positive_prompt"]
    assert any("magetoken" in part for part in payload["positive_prompt"])
    assert any("magic circle" in part for part in payload["positive_prompt"])
    assert payload["lora_calls"] == []
