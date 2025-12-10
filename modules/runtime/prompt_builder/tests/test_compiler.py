import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[4]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from modules.runtime.character_studio import models as character_models
from modules.runtime.character_studio.models import CharacterCard
from modules.runtime.prompt_builder import compiler


@pytest.fixture(autouse=True)
def patch_card_storage(tmp_path, monkeypatch):
    monkeypatch.setattr(character_models, "CARD_STORAGE_ROOT", tmp_path)
    return tmp_path


def test_scene_validation_requires_characters_fields():
    with pytest.raises(ValueError):
        compiler.build_prompt_from_scene(
            {
                "world": "demo",
                "characters": [{"slot_id": 1, "character_id": "abc"}],
            }
        )


def test_scene_validation_rejects_bad_extras():
    with pytest.raises(ValueError):
        compiler.build_prompt_from_scene({"characters": [], "extra_elements": [123]})


def test_prompt_assembly_with_character_card(tmp_path):
    card = CharacterCard(
        id="hero",
        name="Hero",
        nsfw_allowed=False,
        description="brave hero",
        default_prompt_snippet="cinematic lighting",
        trigger_token="herotoken",
        anatomy_tags=["cape"],
        lora_file="hero.safetensors",
        lora_default_strength=0.75,
    )
    card.save(path=tmp_path / "hero" / "card.json")

    scene_json = {
        "world": "fantasy",
        "setting": "castle courtyard",
        "mood": "adventurous",
        "style": "painterly",
        "nsfw_level": "sfw",
        "characters": [
            {
                "slot_id": "protagonist",
                "character_id": "hero",
                "role": "lead",
            }
        ],
        "extra_elements": ["torchlight"],
    }

    compiled = compiler.build_prompt_from_scene(scene_json)
    assert any("world: fantasy" in part for part in compiled.positive_prompt)
    assert any("herotoken" in part for part in compiled.positive_prompt)
    assert any("cape" in part for part in compiled.positive_prompt)
    assert compiled.negative_prompt[-1] == "nsfw"
    assert compiled.lora_calls[0].name == "hero.safetensors"
    assert compiled.lora_calls[0].weight == 0.75


def test_compile_prompt_payload_includes_serialized_loras(tmp_path):
    card = CharacterCard(
        id="hero",
        name="Hero",
        nsfw_allowed=True,
        description="brave hero",
        default_prompt_snippet="cinematic lighting",
        trigger_token="herotoken",
        lora_file="hero.safetensors",
        lora_default_strength=0.75,
    )
    card.save(path=tmp_path / "hero" / "card.json")

    scene_json = {
        "world": "fantasy",
        "setting": "castle courtyard",
        "characters": [
            {
                "slot_id": "protagonist",
                "character_id": "hero",
                "role": "lead",
            }
        ],
        "extra_elements": ["torchlight"],
    }

    payload = compiler.compile_prompt_payload(scene_json)

    assert payload["lora_calls"] == [
        {"name": "hero.safetensors", "weight": 0.75, "trigger": "herotoken"}
    ]
    assert "positive_prompt_text" in payload


def test_apply_feedback_updates_scene_fields():
    scene_json = {
        "world": "demo",
        "setting": "street",
        "mood": "calm",
        "style": None,
        "nsfw_level": None,
        "camera": None,
        "characters": [
            {"slot_id": "hero", "character_id": "c1", "role": "support"}
        ],
        "extra_elements": ["neon"],
    }

    feedback = "mood: dramatic; add elements: rain, fog; character hero: role=antagonist"
    updated = compiler.apply_feedback_to_scene(scene_json, feedback)

    assert updated["mood"] == "dramatic"
    assert "rain" in updated["extra_elements"]
    assert any(character["role"] == "antagonist" for character in updated["characters"])


def test_apply_feedback_requires_text():
    with pytest.raises(ValueError):
        compiler.apply_feedback_to_scene({}, None)
