"""Prompt Builder compiler utilities.

- Purpose: validate scene payloads and convert them into prompt assemblies consumed by launchers.
- Assumptions: Character Card registry paths are available and scene JSON matches expected schema.
- Side effects: none beyond raising validation errors; downstream callers handle disk writes.
"""

from __future__ import annotations

from dataclasses import asdict
from typing import Dict, List, Optional

from modules.runtime.character_studio.registry import CharacterCardRegistry

from .feedback import apply_feedback_to_scene as apply_feedback_to_scene_description
from .llm import SceneLLMAdapter
from .models import CharacterRef, PromptAssembly, SceneDescription, validate_scene


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
    # Normalize top-level scene attributes while preserving unset values as None.
    for key in ["world", "setting", "mood", "style", "nsfw_level", "camera"]:
        validated[key] = _validate_text(scene_json.get(key), key)

    characters = scene_json.get("characters", [])
    if not isinstance(characters, list):
        raise ValueError("characters must be a list")

    validated_characters = []
    # Validate each character mapping to ensure slot references are explicit for pairing.
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
    scene = SceneDescription(
        world=validated.get("world"),
        setting=validated.get("setting"),
        mood=validated.get("mood"),
        style=validated.get("style"),
        nsfw_level=validated.get("nsfw_level"),
        camera=validated.get("camera"),
        characters=characters,
        extra_elements=validated.get("extra_elements", []),
    )
    validate_scene(scene)
    return scene


def parse_scene_description(scene_json: Dict) -> SceneDescription:
    """Public helper to normalize and validate a SceneDescription payload."""

    return _scene_from_json(scene_json)


def build_prompt_from_scene(scene_json: Dict) -> PromptAssembly:
    """Convert a structured SceneDescription into prompts and LoRA calls."""

    scene = _scene_from_json(scene_json)
    adapter = SceneLLMAdapter(card_registry=CharacterCardRegistry())
    cards = adapter.resolve_cards(scene.characters)
    return adapter.synthesize_prompts(scene, cards)


def compile_scene_description(scene: SceneDescription) -> PromptAssembly:
    """Compile a SceneDescription into a PromptAssembly container."""

    validate_scene(scene)
    return build_prompt_from_scene(asdict(scene))


def compile_scene(scene_json: Dict, feedback_text: Optional[str] = None) -> PromptAssembly:
    """Compile a scene payload into a PromptAssembly, applying optional feedback."""

    scene = parse_scene_description(scene_json)
    if feedback_text:
        scene = apply_feedback_to_scene_description(scene, feedback_text)
    return build_prompt_from_scene(asdict(scene))


def compile_prompt_payload(scene_json: Dict, feedback_text: Optional[str] = None) -> Dict[str, object]:
    """Compile a scene payload into a JSON-ready prompt bundle.

    Accepts an optional ``feedback_text`` to adjust the scene before compilation.
    """

    scene = parse_scene_description(scene_json)
    if feedback_text:
        scene = apply_feedback_to_scene_description(scene, feedback_text)

    assembly = build_prompt_from_scene(asdict(scene))
    return assembly.to_payload()


def apply_feedback_to_scene(scene_json: Dict, feedback_text: str) -> Dict:
    """Use natural language feedback to refine a SceneDescription payload via the LLM adapter."""

    scene = _scene_from_json(scene_json)
    updated_scene = apply_feedback_to_scene_description(scene, feedback_text)
    return asdict(updated_scene)


def build_scene_from_quick_prompt(payload: Dict[str, object]) -> SceneDescription:
    """Build a SceneDescription from a lightweight quick prompt payload."""

    if not isinstance(payload, dict):
        raise ValueError("payload must be a JSON object")

    prompt_text = _validate_text(payload.get("prompt"), "prompt")
    if not prompt_text:
        raise ValueError("prompt is required")

    extra_elements: List[str] = [prompt_text]
    extras = payload.get("extra_elements", [])
    if isinstance(extras, str):
        extras = [value.strip() for value in extras.split(",") if value.strip()]
    if extras:
        if not isinstance(extras, list):
            raise ValueError("extra_elements must be a list of strings")
        for idx, element in enumerate(extras):
            if not isinstance(element, str):
                raise ValueError(f"extra_elements[{idx}] must be a string")
            if element.strip():
                extra_elements.append(element.strip())

    characters: List[Dict[str, str]] = []
    character_ids = payload.get("character_ids", []) or []
    if isinstance(character_ids, str):
        character_ids = [value.strip() for value in character_ids.split(",") if value.strip()]
    if character_ids:
        if not isinstance(character_ids, list):
            raise ValueError("character_ids must be a list of strings")
        for idx, character_id in enumerate(character_ids):
            if not isinstance(character_id, str) or not character_id.strip():
                raise ValueError(f"character_ids[{idx}] must be a non-empty string")
            characters.append({"slot_id": f"character-{idx + 1}", "character_id": character_id.strip()})

    scene_json: Dict[str, object] = {
        "world": payload.get("world"),
        "setting": payload.get("setting"),
        "mood": payload.get("mood"),
        "style": payload.get("style"),
        "nsfw_level": payload.get("nsfw_level"),
        "camera": payload.get("camera"),
        "characters": characters,
        "extra_elements": extra_elements,
    }
    return _scene_from_json(scene_json)


def compile_quick_prompt_payload(payload: Dict[str, object]) -> Dict[str, object]:
    """Compile a quick prompt payload into prompt bundle data."""

    scene = build_scene_from_quick_prompt(payload)
    assembly = build_prompt_from_scene(asdict(scene))
    return {"scene": asdict(scene), "assembly": assembly.to_payload()}
