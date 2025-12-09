import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[4]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from modules.runtime.prompt_builder.models import (  # noqa: E402
    CharacterRef,
    LoRACall,
    PromptAssembly,
    SceneDescription,
    validate_scene,
)


def test_validate_scene_rejects_empty_slot():
    scene = SceneDescription(characters=[CharacterRef(slot_id="", character_id="abc")])

    with pytest.raises(ValueError, match="slot_id must be a non-empty string"):
        validate_scene(scene)


def test_prompt_assembly_rejects_non_string_prompt_parts():
    assembly = PromptAssembly(positive_prompt=["ok", 123], negative_prompt=["bad"])

    with pytest.raises(ValueError, match=r"positive_prompt\[1\] must be a string"):
        assembly.to_payload()


def test_prompt_assembly_valid_payload_roundtrip():
    assembly = PromptAssembly(
        positive_prompt=["world: demo"],
        negative_prompt=["nsfw"],
        lora_calls=[LoRACall(name="style")],
    )

    payload = assembly.to_payload()

    assert payload["positive_prompt"] == ["world: demo"]
    assert payload["negative_prompt_text"] == "nsfw"
    assert payload["lora_calls"][0]["name"] == "style"
