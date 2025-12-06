"""Character Studio models."""

from dataclasses import dataclass, field
from typing import List, Optional

# TODO: expose CharacterCard through a shared registry for use by Prompt Builder and other modules.


@dataclass
class CharacterCard:
    id: str
    name: str
    age: Optional[str] = None
    nsfw_allowed: bool = False
    description: Optional[str] = None
    default_prompt_snippet: Optional[str] = None
    trigger_token: Optional[str] = None
    anatomy_tags: List[str] = field(default_factory=list)
    lora_file: Optional[str] = None
    lora_default_strength: Optional[float] = None
    reference_images: List[str] = field(default_factory=list)


def apply_feedback_to_character(character_card: CharacterCard, feedback_text: str) -> CharacterCard:
    """Refine a Character Card using natural language feedback.

    TODO: Call the shared LLM abstraction to adjust description, default prompt snippet,
    and anatomy_tags based on feedback, then persist the updated Character Card.
    """

    raise NotImplementedError
