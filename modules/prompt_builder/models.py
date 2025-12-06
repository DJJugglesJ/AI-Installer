"""Data models for Prompt Builder."""

from dataclasses import dataclass, field
from typing import List, Optional

# TODO: share CharacterCard import from character_studio registry once available.


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
