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

    def to_payload(self) -> Dict[str, object]:
        """Serialize the prompt assembly into a JSON-friendly payload.

        The payload preserves the list-oriented schema for prompts and exposes
        concatenated text variants so shell launchers can consume the bundle
        without recomputing joins.
        """

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
