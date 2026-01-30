"""Character Studio service helpers for card creation and updates."""

from __future__ import annotations

from pathlib import Path
from typing import Dict, List, Optional

from .models import CARD_STORAGE_ROOT, CharacterCard


def _normalize_string_list(value: object, field_name: str) -> List[str]:
    if value is None:
        return []
    if not isinstance(value, list):
        raise ValueError(f"{field_name} must be a list of strings")
    normalized: List[str] = []
    for idx, item in enumerate(value):
        if not isinstance(item, str) or not item.strip():
            raise ValueError(f"{field_name}[{idx}] must be a non-empty string")
        normalized.append(item.strip())
    return normalized


def _apply_card_updates(card: CharacterCard, payload: Dict[str, object]) -> CharacterCard:
    updates = dict(card.to_dict())

    if "name" in payload:
        updates["name"] = payload.get("name")
    if "age" in payload:
        updates["age"] = payload.get("age")
    if "nsfw_allowed" in payload:
        if not isinstance(payload.get("nsfw_allowed"), bool):
            raise ValueError("nsfw_allowed must be a boolean")
        updates["nsfw_allowed"] = payload.get("nsfw_allowed")
    if "description" in payload:
        updates["description"] = payload.get("description")
    if "default_prompt_snippet" in payload:
        updates["default_prompt_snippet"] = payload.get("default_prompt_snippet")
    if "trigger_token" in payload:
        updates["trigger_token"] = payload.get("trigger_token")
    if "trigger_tokens" in payload:
        updates["trigger_tokens"] = _normalize_string_list(payload.get("trigger_tokens"), "trigger_tokens")
    if "anatomy_tags" in payload:
        updates["anatomy_tags"] = _normalize_string_list(payload.get("anatomy_tags"), "anatomy_tags")
    if "wardrobe" in payload:
        updates["wardrobe"] = _normalize_string_list(payload.get("wardrobe"), "wardrobe")
    if "reference_images" in payload:
        updates["reference_images"] = _normalize_string_list(payload.get("reference_images"), "reference_images")
    if "lora_file" in payload:
        updates["lora_file"] = payload.get("lora_file")
    if "lora_default_strength" in payload:
        updates["lora_default_strength"] = payload.get("lora_default_strength")
    if "metadata" in payload:
        metadata = payload.get("metadata") or {}
        if not isinstance(metadata, dict):
            raise ValueError("metadata must be an object")
        updates["metadata"] = {str(key): str(value) for key, value in metadata.items()}

    updated = CharacterCard.from_dict(updates)
    updated.validate()
    return updated


def upsert_character_card(payload: Dict[str, object], storage_root: Optional[Path] = None) -> CharacterCard:
    if not isinstance(payload, dict):
        raise ValueError("payload must be a JSON object")

    card_id = payload.get("id")
    if not isinstance(card_id, str) or not card_id.strip():
        raise ValueError("id is required")

    storage_root = Path(storage_root) if storage_root else CARD_STORAGE_ROOT
    card_path = storage_root / card_id / "card.json"
    if card_path.exists():
        card = CharacterCard.load(card_id, path=card_path)
    else:
        name = payload.get("name")
        if not isinstance(name, str) or not name.strip():
            raise ValueError("name is required when creating a new card")
        trigger_token = payload.get("trigger_token")
        trigger_tokens = _normalize_string_list(payload.get("trigger_tokens"), "trigger_tokens")
        if trigger_token and trigger_token not in trigger_tokens:
            trigger_tokens.insert(0, trigger_token)

        card = CharacterCard(
            id=card_id,
            name=name.strip(),
            nsfw_allowed=bool(payload.get("nsfw_allowed", False)),
            anatomy_tags=_normalize_string_list(payload.get("anatomy_tags"), "anatomy_tags"),
            wardrobe=_normalize_string_list(payload.get("wardrobe"), "wardrobe"),
            trigger_token=trigger_token or (trigger_tokens[0] if trigger_tokens else None),
            trigger_tokens=trigger_tokens,
            reference_images=_normalize_string_list(payload.get("reference_images"), "reference_images"),
            description=payload.get("description"),
            default_prompt_snippet=payload.get("default_prompt_snippet"),
            lora_file=payload.get("lora_file"),
            lora_default_strength=payload.get("lora_default_strength"),
            metadata={str(key): str(value) for key, value in (payload.get("metadata") or {}).items()},
        )

    updated = _apply_card_updates(card, payload)
    updated.save(path=card_path)
    return updated
