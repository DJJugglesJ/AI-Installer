"""Prompt Builder compiler utilities."""

from __future__ import annotations

import re
from typing import Dict, Iterable, List, Optional

from modules.character_studio.models import CharacterCard

from .models import LoRACall, PromptAssembly, SceneDescription

# TODO: import shared Character Card registry abstraction once available.


def _validate_text(value: object, field_name: str) -> Optional[str]:
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

    validated_characters: List[Dict[str, object]] = []
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


def _load_character_cards(characters: Iterable[Dict[str, object]]) -> Dict[str, CharacterCard]:
    cards: Dict[str, CharacterCard] = {}
    for character in characters:
        character_id = character.get("character_id")
        if not character_id or not isinstance(character_id, str):
            continue
        try:
            cards[character_id] = CharacterCard.load(character_id)
        except FileNotFoundError:
            continue
    return cards


def _character_prompt_snippet(character: Dict[str, object], card: Optional[CharacterCard]) -> str:
    override_snippet = character.get("override_prompt_snippet")
    parts: List[str] = []
    if card:
        if card.trigger_token:
            parts.append(card.trigger_token)
        parts.extend(filter(None, [override_snippet or card.default_prompt_snippet, card.description]))
        if card.anatomy_tags:
            parts.append(", ".join(card.anatomy_tags))
    else:
        parts.append(str(character.get("character_id")))
        if override_snippet:
            parts.append(str(override_snippet))
    role = character.get("role")
    if role:
        parts.append(f"role: {role}")
    return " | ".join([segment for segment in parts if segment])


def _derive_lora_calls(cards: Dict[str, CharacterCard], characters: Iterable[Dict[str, object]]) -> List[LoRACall]:
    loras: List[LoRACall] = []
    for character in characters:
        character_id = character.get("character_id")
        card = cards.get(character_id)
        if not card or not card.lora_file:
            continue
        loras.append(
            LoRACall(
                name=card.lora_file,
                weight=card.lora_default_strength,
                trigger=card.trigger_token,
            )
        )
    return loras


def build_prompt_from_scene(scene_json: Dict) -> Dict[str, Optional[List[str]]]:
    """Convert a structured SceneDescription into prompts and LoRA calls."""

    validated = _validate_scene_json(scene_json)
    cards = _load_character_cards(validated.get("characters", []))

    positive_prompt: List[str] = []
    context_parts = [
        f"world: {validated['world']}" if validated.get("world") else None,
        f"setting: {validated['setting']}" if validated.get("setting") else None,
        f"mood: {validated['mood']}" if validated.get("mood") else None,
        f"style: {validated['style']}" if validated.get("style") else None,
        f"camera: {validated['camera']}" if validated.get("camera") else None,
    ]
    combined_context = "; ".join([part for part in context_parts if part])
    if combined_context:
        positive_prompt.append(combined_context)

    for character in validated.get("characters", []):
        card = cards.get(character.get("character_id"))
        snippet = _character_prompt_snippet(character, card)
        if snippet:
            positive_prompt.append(snippet)

    extras = validated.get("extra_elements", [])
    if extras:
        positive_prompt.append("extras: " + ", ".join(extras))

    negative_prompt = ["low quality", "blurry"]
    if validated.get("nsfw_level") in {"sfw", "safe"}:
        negative_prompt.append("nsfw")
    if any(card for card in cards.values() if not card.nsfw_allowed and validated.get("nsfw_level") not in {None, "sfw", "safe"}):
        negative_prompt.append("explicit content")

    lora_calls = _derive_lora_calls(cards, validated.get("characters", []))

    return {
        "positive_prompt": positive_prompt,
        "negative_prompt": negative_prompt,
        "lora_calls": lora_calls,
    }


def compile_scene_description(scene: SceneDescription) -> PromptAssembly:
    """Compile a SceneDescription into a PromptAssembly container."""

    compiled = build_prompt_from_scene(scene.__dict__)
    return PromptAssembly(
        positive_prompt=list(compiled.get("positive_prompt") or []),
        negative_prompt=list(compiled.get("negative_prompt") or []),
        lora_calls=[LoRACall(name=call) if isinstance(call, str) else call for call in (compiled.get("lora_calls") or [])],
    )


def apply_feedback_to_scene(scene_json: Dict, feedback_text: str) -> Dict:
    """Use natural language feedback to refine a SceneDescription payload.

    TODO: Use the LLM abstraction to apply natural language feedback to the SceneDescription
    and return an updated SceneDescription JSON. This should adjust fields like character traits,
    style, mood, etc., based on the feedback, without implementing the full logic yet.
    """

    updated = {**scene_json}
    if not feedback_text or not feedback_text.strip():
        return updated

    directives = re.split(r"[\n;]+", feedback_text)
    for directive in directives:
        if ":" not in directive:
            continue
        key, value = directive.split(":", 1)
        key = key.strip().lower()
        value = value.strip()
        if not value:
            continue

        if key in {"world", "setting", "mood", "style", "camera", "nsfw_level"}:
            updated[key] = value
        elif key in {"add element", "add elements", "elements", "extra", "extra_elements"}:
            extras = list(updated.get("extra_elements", []) or [])
            for part in [v.strip() for v in value.split(",") if v.strip()]:
                if part not in extras:
                    extras.append(part)
            updated["extra_elements"] = extras
        elif key.startswith("character"):
            # Accept directives like "character hero: role=antagonist" or "character hero: override_prompt_snippet=serene"
            _, _, remainder = key.partition(" ")
            target_slot = remainder.strip()
            if not target_slot:
                continue
            characters = list(updated.get("characters", []) or [])
            for character in characters:
                if str(character.get("slot_id")) == target_slot:
                    if "role=" in value:
                        character["role"] = value.split("role=", 1)[1].strip()
                    elif "override_prompt_snippet=" in value:
                        character["override_prompt_snippet"] = value.split("override_prompt_snippet=", 1)[1].strip()
            updated["characters"] = characters

    return updated
