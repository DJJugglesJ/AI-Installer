"""Shared data models for the Prompt Builder module.

- Purpose: define serializable structures for scenes, character references, and compiled prompt bundles.
- Assumptions: dataclass consumers will serialize via ``asdict`` and lists remain order-sensitive.
- Side effects: none; classes are passive containers.
"""

from dataclasses import asdict, dataclass, field
from typing import Dict, List, Optional


@dataclass
class CharacterRef:
    slot_id: str
    character_id: str
    role: Optional[str] = None
    override_prompt_snippet: Optional[str] = None


def validate_character_ref(character: "CharacterRef") -> None:
    """Validate a CharacterRef instance for required identifiers."""

    if not isinstance(character.slot_id, str) or not character.slot_id.strip():
        raise ValueError("character.slot_id must be a non-empty string")
    if not isinstance(character.character_id, str) or not character.character_id.strip():
        raise ValueError("character.character_id must be a non-empty string")

    if character.role is not None and not isinstance(character.role, str):
        raise ValueError("character.role must be a string or None")
    if character.override_prompt_snippet is not None and not isinstance(
        character.override_prompt_snippet, str
    ):
        raise ValueError("character.override_prompt_snippet must be a string or None")


@dataclass
class SceneDescription:
    world: Optional[str] = None
    setting: Optional[str] = None
    mood: Optional[str] = None
    style: Optional[str] = None
    nsfw_level: Optional[str] = None
    camera: Optional[str] = None
    characters: List[CharacterRef] = field(default_factory=list)
    extra_elements: List[str] = field(default_factory=list)


def _validate_optional_text(value: Optional[str], field_name: str) -> None:
    if value is not None and not isinstance(value, str):
        raise ValueError(f"{field_name} must be a string or None")


def validate_scene(scene: "SceneDescription") -> None:
    """Validate a SceneDescription instance and its nested values."""

    if not isinstance(scene.characters, list):
        raise ValueError("characters must be a list")
    for idx, character in enumerate(scene.characters):
        if not isinstance(character, CharacterRef):
            raise ValueError(f"characters[{idx}] must be a CharacterRef")
        validate_character_ref(character)

    if not isinstance(scene.extra_elements, list):
        raise ValueError("extra_elements must be a list")
    for idx, element in enumerate(scene.extra_elements):
        if not isinstance(element, str) or not element.strip():
            raise ValueError(f"extra_elements[{idx}] must be a non-empty string")

    _validate_optional_text(scene.world, "world")
    _validate_optional_text(scene.setting, "setting")
    _validate_optional_text(scene.mood, "mood")
    _validate_optional_text(scene.style, "style")
    _validate_optional_text(scene.nsfw_level, "nsfw_level")
    _validate_optional_text(scene.camera, "camera")


@dataclass
class LoRACall:
    """Represents a LoRA invocation with optional weights or triggers."""

    name: str
    weight: Optional[float] = None
    trigger: Optional[str] = None


@dataclass
class PromptAssembly:
    """Compiled prompt bundle ready for consumption by launcher scripts."""

    positive_prompt: List[str] = field(default_factory=list)
    negative_prompt: List[str] = field(default_factory=list)
    lora_calls: List[LoRACall] = field(default_factory=list)

    def validate(self) -> None:
        """Validate prompt lists and LoRA call structure before serialization."""

        self._validate_prompt_list(self.positive_prompt, "positive_prompt")
        self._validate_prompt_list(self.negative_prompt, "negative_prompt")

        if not isinstance(self.lora_calls, list):
            raise ValueError("lora_calls must be a list")
        for idx, call in enumerate(self.lora_calls):
            if not isinstance(call, LoRACall):
                raise ValueError(f"lora_calls[{idx}] must be a LoRACall")

    @staticmethod
    def _validate_prompt_list(values: List[str], field_name: str) -> None:
        if not isinstance(values, list):
            raise ValueError(f"{field_name} must be a list of strings")
        for idx, value in enumerate(values):
            if not isinstance(value, str):
                raise ValueError(f"{field_name}[{idx}] must be a string")

    def to_payload(self) -> Dict[str, object]:
        """Serialize the prompt assembly into a JSON-friendly payload.

        The payload preserves the list-oriented schema for prompts and exposes
        concatenated text variants so shell launchers can consume the bundle
        without recomputing joins.
        """

        self.validate()
        positive_parts = [part for part in self.positive_prompt if part]
        negative_parts = [part for part in self.negative_prompt if part]
        lora_payload = [asdict(call) for call in self.lora_calls]

        return {
            "positive_prompt": positive_parts,
            "negative_prompt": negative_parts,
            "lora_calls": lora_payload,
            "positive_prompt_text": " | ".join(positive_parts),
            "negative_prompt_text": " | ".join(negative_parts),
        }
