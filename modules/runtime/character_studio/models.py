"""Character Studio models and serialization helpers."""

from __future__ import annotations

import json
import re
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Dict, List, Optional


CARD_STORAGE_ROOT = Path(__file__).resolve().parent / "character_cards"
CARD_STORAGE_ROOT.mkdir(exist_ok=True)


class CharacterStudioError(Exception):
    """Base error for Character Studio operations with optional context."""

    def __init__(self, message: str, *, context: Optional[Dict[str, object]] = None) -> None:
        super().__init__(message)
        self.context = context or {}


class SchemaValidationError(CharacterStudioError):
    """Raised when Character Cards do not satisfy the shared schema."""


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
        "trigger_tokens": {
            "type": "array",
            "items": {"type": "string"},
            "description": "Optional additional trigger tokens that work with this character.",
        },
        "anatomy_tags": {
            "type": "array",
            "items": {"type": "string"},
            "description": "Tags describing anatomy, outfits, accessories, and style cues.",
        },
        "wardrobe": {
            "type": "array",
            "items": {"type": "string"},
            "description": "List of default outfits or wardrobe descriptors maintained per character.",
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
    trigger_tokens: List[str] = field(default_factory=list)
    anatomy_tags: List[str] = field(default_factory=list)
    wardrobe: List[str] = field(default_factory=list)
    lora_file: Optional[str] = None
    lora_default_strength: Optional[float] = None
    reference_images: List[str] = field(default_factory=list)
    metadata: Dict[str, str] = field(default_factory=dict)

    def normalize_triggers(self) -> None:
        """Normalize trigger token fields to keep them consistent."""

        self.trigger_token, self.trigger_tokens = _normalize_trigger_fields(
            self.trigger_token,
            self.trigger_tokens,
        )

    def validate(self) -> None:
        """Validate the Character Card against the shared schema."""

        errors = []
        if not isinstance(self.id, str) or not self.id.strip():
            errors.append("id must be a non-empty string")
        if not isinstance(self.name, str) or not self.name.strip():
            errors.append("name must be a non-empty string")
        if not isinstance(self.nsfw_allowed, bool):
            errors.append("nsfw_allowed must be a boolean")
        if self.trigger_token is not None and not isinstance(self.trigger_token, str):
            errors.append("trigger_token must be a string or None")
        if not isinstance(self.trigger_tokens, list) or not all(
            isinstance(token, str) and token.strip() for token in self.trigger_tokens
        ):
            errors.append("trigger_tokens must be a list of non-empty strings")
        if self.trigger_token and self.trigger_token not in self.trigger_tokens:
            errors.append("trigger_token must be included in trigger_tokens")
        if not isinstance(self.anatomy_tags, list) or not all(
            isinstance(tag, str) and tag.strip() for tag in self.anatomy_tags
        ):
            errors.append("anatomy_tags must be a list of non-empty strings")
        if not isinstance(self.wardrobe, list) or not all(
            isinstance(item, str) and item.strip() for item in self.wardrobe
        ):
            errors.append("wardrobe must be a list of non-empty strings")
        if not isinstance(self.reference_images, list) or not all(
            isinstance(item, str) and item.strip() for item in self.reference_images
        ):
            errors.append("reference_images must be a list of non-empty strings")

        if errors:
            raise SchemaValidationError("Character Card validation failed", context={"errors": errors, "card_id": self.id})

    def to_dict(self) -> Dict[str, object]:
        """Serialize the CharacterCard into a JSON-compatible dict."""

        payload = asdict(self)
        trigger_token, trigger_tokens = _normalize_trigger_fields(
            payload.get("trigger_token"),
            payload.get("trigger_tokens", []),
        )
        payload["trigger_token"] = trigger_token
        payload["trigger_tokens"] = trigger_tokens
        return payload

    @classmethod
    def from_dict(cls, payload: Dict[str, object]) -> "CharacterCard":
        """Create a CharacterCard from a JSON-compatible dict."""

        trigger_token, trigger_tokens = _normalize_trigger_fields(
            payload.get("trigger_token"),
            payload.get("trigger_tokens", []),
        )

        return cls(
            id=str(payload.get("id")),
            name=str(payload.get("name")),
            age=payload.get("age"),
            nsfw_allowed=bool(payload.get("nsfw_allowed", False)),
            description=payload.get("description"),
            default_prompt_snippet=payload.get("default_prompt_snippet"),
            trigger_token=trigger_token,
            trigger_tokens=trigger_tokens,
            anatomy_tags=list(payload.get("anatomy_tags", []) or []),
            wardrobe=list(payload.get("wardrobe", []) or []),
            lora_file=payload.get("lora_file"),
            lora_default_strength=payload.get("lora_default_strength"),
            reference_images=list(payload.get("reference_images", []) or []),
            metadata=dict(payload.get("metadata", {}) or {}),
        )

    def save(self, path: Optional[Path] = None) -> Path:
        """Persist the CharacterCard to disk as JSON and return the saved path."""

        self.normalize_triggers()
        self.validate()
        destination = path or CARD_STORAGE_ROOT / self.id / "card.json"
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(self.to_dict(), indent=2), encoding="utf-8")
        return destination

    @classmethod
    def load(cls, card_id: str, path: Optional[Path] = None) -> "CharacterCard":
        """Load a CharacterCard from disk by id."""

        source = path or CARD_STORAGE_ROOT / card_id / "card.json"
        payload = json.loads(source.read_text(encoding="utf-8"))
        card = cls.from_dict(payload)
        card.validate()
        return card


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
        elif key in {"trigger_tokens", "triggers"}:
            additions = [v.strip() for v in value.split(",") if v.strip()]
            updated.trigger_tokens = additions
            updated.trigger_token = additions[0] if additions else updated.trigger_token
        elif key in {"nsfw", "nsfw_allowed"}:
            updated.nsfw_allowed = value.lower() in {"true", "1", "yes", "y", "allow"}
        elif key in {"tag", "anatomy_tag", "anatomy_tags", "tags"}:
            additions = [v.strip() for v in value.split(",") if v.strip()]
            for tag in additions:
                if tag not in updated.anatomy_tags:
                    updated.anatomy_tags.append(tag)
        elif key in {"wardrobe"}:
            additions = [v.strip() for v in value.split(",") if v.strip()]
            for item in additions:
                if item not in updated.wardrobe:
                    updated.wardrobe.append(item)
        elif key in {"reference_images", "reference_image"}:
            additions = [v.strip() for v in value.split(",") if v.strip()]
            for path in additions:
                if path not in updated.reference_images:
                    updated.reference_images.append(path)
        elif key.startswith("metadata"):
            # Accept directives like "metadata.version: 1.0"
            metadata_key = key.split(".", maxsplit=1)[1] if "." in key else "note"
            updated.metadata[metadata_key] = value

    return updated


def _normalize_trigger_fields(
    trigger_token: Optional[object],
    trigger_tokens: object,
) -> tuple[Optional[str], List[str]]:
    normalized_token = None
    if isinstance(trigger_token, str) and trigger_token.strip():
        normalized_token = trigger_token.strip()

    tokens_source = trigger_tokens if isinstance(trigger_tokens, list) else []
    normalized_tokens: List[str] = []
    seen = set()
    for token in tokens_source:
        if not isinstance(token, str):
            continue
        cleaned = token.strip()
        if not cleaned or cleaned in seen:
            continue
        normalized_tokens.append(cleaned)
        seen.add(cleaned)

    if normalized_token:
        if normalized_token not in seen:
            normalized_tokens.insert(0, normalized_token)
    elif normalized_tokens:
        normalized_token = normalized_tokens[0]

    return normalized_token, normalized_tokens
