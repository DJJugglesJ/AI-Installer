"""Character Studio models and serialization helpers."""

from __future__ import annotations

import json
import re
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Dict, List, Optional


CARD_STORAGE_ROOT = Path(__file__).resolve().parent / "character_cards"
CARD_STORAGE_ROOT.mkdir(exist_ok=True)


# Shared JSON Schema for use by Prompt Builder and other modules.
CHARACTER_CARD_SCHEMA: Dict[str, object] = {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "title": "CharacterCard",
    "type": "object",
    "required": ["id", "name", "nsfw_allowed", "anatomy_tags"],
    "properties": {
        "id": {"type": "string", "description": "Stable identifier used across tools."},
        "name": {"type": "string", "description": "Character display name."},
        "age": {"type": ["string", "null"], "description": "Age or age range."},
        "nsfw_allowed": {
            "type": "boolean",
            "description": "Whether NSFW prompts and outputs are permitted for this character.",
        },
        "description": {
            "type": ["string", "null"],
            "description": "Natural language character summary for Prompt Builder context.",
        },
        "default_prompt_snippet": {
            "type": ["string", "null"],
            "description": "Reusable prompt fragment appended when invoking this character.",
        },
        "trigger_token": {
            "type": ["string", "null"],
            "description": "Token or keyword that reliably summons the character in prompts.",
        },
        "anatomy_tags": {
            "type": "array",
            "items": {"type": "string"},
            "description": "Tags describing anatomy, outfits, accessories, and style cues.",
        },
        "lora_file": {
            "type": ["string", "null"],
            "description": "Optional LoRA checkpoint used with the character.",
        },
        "lora_default_strength": {
            "type": ["number", "null"],
            "description": "Default strength for LoRA application.",
        },
        "reference_images": {
            "type": "array",
            "items": {"type": "string"},
            "description": "List of reference image paths saved alongside the card.",
        },
        "metadata": {
            "type": "object",
            "additionalProperties": {"type": "string"},
            "description": "Additional metadata (creator, version, notes) shared across modules.",
        },
    },
}


@dataclass
class CharacterCard:
    """Represent a reusable Character Card shared across modules."""

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
    metadata: Dict[str, str] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, object]:
        """Serialize the CharacterCard into a JSON-compatible dict."""

        return asdict(self)

    @classmethod
    def from_dict(cls, payload: Dict[str, object]) -> "CharacterCard":
        """Create a CharacterCard from a JSON-compatible dict."""

        return cls(
            id=str(payload.get("id")),
            name=str(payload.get("name")),
            age=payload.get("age"),
            nsfw_allowed=bool(payload.get("nsfw_allowed", False)),
            description=payload.get("description"),
            default_prompt_snippet=payload.get("default_prompt_snippet"),
            trigger_token=payload.get("trigger_token"),
            anatomy_tags=list(payload.get("anatomy_tags", []) or []),
            lora_file=payload.get("lora_file"),
            lora_default_strength=payload.get("lora_default_strength"),
            reference_images=list(payload.get("reference_images", []) or []),
            metadata=dict(payload.get("metadata", {}) or {}),
        )

    def save(self, path: Optional[Path] = None) -> Path:
        """Persist the CharacterCard to disk as JSON and return the saved path."""

        destination = path or CARD_STORAGE_ROOT / self.id / "card.json"
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(self.to_dict(), indent=2), encoding="utf-8")
        return destination

    @classmethod
    def load(cls, card_id: str, path: Optional[Path] = None) -> "CharacterCard":
        """Load a CharacterCard from disk by id."""

        source = path or CARD_STORAGE_ROOT / card_id / "card.json"
        payload = json.loads(source.read_text(encoding="utf-8"))
        return cls.from_dict(payload)


def apply_feedback_to_character(character_card: CharacterCard, feedback_text: str) -> CharacterCard:
    """Apply structured feedback to update a Character Card.

    The function supports simple key/value directives separated by semicolons or newlines. Example:
    ``anatomy_tags: windswept hair, silver eyes; description: moodier lighting; nsfw_allowed: false``
    """

    if not feedback_text.strip():
        return character_card

    directives = re.split(r"[\n;]+", feedback_text)
    updates: Dict[str, str] = {}
    for directive in directives:
        if ":" not in directive:
            continue
        key, value = directive.split(":", 1)
        updates[key.strip().lower()] = value.strip()

    updated = CharacterCard(**character_card.to_dict())

    for key, value in updates.items():
        if key in {"description", "default_prompt_snippet", "trigger_token", "age", "name"}:
            setattr(updated, key, value)
        elif key in {"nsfw", "nsfw_allowed"}:
            updated.nsfw_allowed = value.lower() in {"true", "1", "yes", "y", "allow"}
        elif key in {"tag", "anatomy_tag", "anatomy_tags", "tags"}:
            additions = [v.strip() for v in value.split(",") if v.strip()]
            for tag in additions:
                if tag not in updated.anatomy_tags:
                    updated.anatomy_tags.append(tag)
        elif key.startswith("metadata"):
            # Accept directives like "metadata.version: 1.0"
            metadata_key = key.split(".", maxsplit=1)[1] if "." in key else "note"
            updated.metadata[metadata_key] = value

    return updated
