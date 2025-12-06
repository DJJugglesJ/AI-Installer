"""Prompt Builder compiler utilities."""

from __future__ import annotations

from dataclasses import asdict
from typing import Dict

from modules.character_studio.registry import CharacterCardRegistry

from .llm import SceneLLMAdapter
from .models import CharacterRef, PromptAssembly, SceneDescription


def _validate_text(value: object, field_name: str):
    if value is None:
        return None
    if not isinstance(value, str):
        raise ValueError(f"{field_name} must be a string or null")
    return value.strip() or None


def _validate_scene_json(scene_json: Dict) -> Dict:
    if not isinstance(scene_json, dict):
        raise ValueError("scene_json must be a dictionary")

    validated: Dict[str, object] = {}
    for key in ["world", "setting", "mood", "style", "nsfw_level", "camera"]:
        validated[key] = _validate_text(scene_json.get(key), key)

    characters = scene_json.get("characters", [])
    if not isinstance(characters, list):
        raise ValueError("characters must be a list")

    validated_characters = []
    for idx, character in enumerate(characters):
        if not isinstance(character, dict):
            raise ValueError(f"characters[{idx}] must be a dictionary")
        slot_id = character.get("slot_id")
        character_id = character.get("character_id")
        if not isinstance(slot_id, str) or not slot_id.strip():
            raise ValueError(f"characters[{idx}].slot_id is required")
        if not isinstance(character_id, str) or not character_id.strip():
            raise ValueError(f"characters[{idx}].character_id is required")

        validated_characters.append(
            {
                "slot_id": slot_id.strip(),
                "character_id": character_id.strip(),
                "role": _validate_text(character.get("role"), f"characters[{idx}].role"),
                "override_prompt_snippet": _validate_text(
                    character.get("override_prompt_snippet"), f"characters[{idx}].override_prompt_snippet"
                ),
            }
        )

    extra_elements = scene_json.get("extra_elements", [])
    if not isinstance(extra_elements, list):
        raise ValueError("extra_elements must be a list")
    for idx, element in enumerate(extra_elements):
        if not isinstance(element, str):
            raise ValueError(f"extra_elements[{idx}] must be a string")

    validated["characters"] = validated_characters
    validated["extra_elements"] = [element.strip() for element in extra_elements if element.strip()]
    return validated


def _scene_from_json(scene_json: Dict) -> SceneDescription:
    validated = _validate_scene_json(scene_json)
    characters = [CharacterRef(**character) for character in validated.get("characters", [])]
    return SceneDescription(
        world=validated.get("world"),
        setting=validated.get("setting"),
        mood=validated.get("mood"),
        style=validated.get("style"),
        nsfw_level=validated.get("nsfw_level"),
        camera=validated.get("camera"),
        characters=characters,
        extra_elements=validated.get("extra_elements", []),
    )


def build_prompt_from_scene(scene_json: Dict) -> PromptAssembly:
    """Convert a structured SceneDescription into prompts and LoRA calls."""

    scene = _scene_from_json(scene_json)
    adapter = SceneLLMAdapter(card_registry=CharacterCardRegistry())
    cards = adapter.resolve_cards(scene.characters)
    return adapter.synthesize_prompts(scene, cards)


def compile_scene_description(scene: SceneDescription) -> PromptAssembly:
    """Compile a SceneDescription into a PromptAssembly container."""

    return build_prompt_from_scene(asdict(scene))


def apply_feedback_to_scene(scene_json: Dict, feedback_text: str) -> Dict:
    """Use natural language feedback to refine a SceneDescription payload via the LLM adapter."""

    scene = _scene_from_json(scene_json)
    adapter = SceneLLMAdapter(card_registry=CharacterCardRegistry())
    updated_scene = adapter.apply_feedback(scene, feedback_text)
    return asdict(updated_scene)
