"""Feedback provider interfaces for Prompt Builder and Character Studio.

- Purpose: select feedback providers and apply structured feedback updates.
- Assumptions: callers pass validated payloads; provider configs are structured JSON.
- Side effects: none; providers return updated copies only.
"""

from __future__ import annotations

import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Dict, Mapping, Optional, Protocol, Tuple

from modules.config_service import config_service

from .models import CharacterRef, SceneDescription


@dataclass(frozen=True)
class ProviderConfig:
    provider: str
    fallback_provider: str
    providers: Dict[str, Dict[str, Any]]


class FeedbackProvider(Protocol):
    name: str

    def apply_scene_feedback(self, scene: SceneDescription, feedback_text: str) -> SceneDescription:
        """Apply feedback to a SceneDescription and return an updated copy."""

    def apply_character_feedback(self, character_payload: Dict[str, object], feedback_text: str) -> Dict[str, object]:
        """Apply feedback to a CharacterCard payload and return an updated copy."""


class DeterministicFeedbackProvider:
    """Deterministic fallback provider using directive-style feedback."""

    name = "deterministic"

    def __init__(self, settings: Optional[Mapping[str, Any]] = None) -> None:
        self.settings = dict(settings or {})

    def apply_scene_feedback(self, scene: SceneDescription, feedback_text: str) -> SceneDescription:
        from . import compiler

        updated = compiler.apply_feedback_to_scene(scene, feedback_text)
        if isinstance(updated, compiler.Error):
            raise ValueError(updated.error)
        return updated

    def apply_character_feedback(self, character_payload: Dict[str, object], feedback_text: str) -> Dict[str, object]:
        return _apply_character_directives(character_payload, feedback_text)


class PresetFeedbackProvider:
    """Use structured config overrides keyed by feedback text."""

    name = "preset"

    def __init__(self, settings: Optional[Mapping[str, Any]] = None) -> None:
        settings = settings or {}
        self.scene_overrides = settings.get("scene_overrides", {}) if isinstance(settings, dict) else {}
        self.character_overrides = settings.get("character_overrides", {}) if isinstance(settings, dict) else {}

    def apply_scene_feedback(self, scene: SceneDescription, feedback_text: str) -> SceneDescription:
        if not feedback_text:
            return scene
        update = self.scene_overrides.get(feedback_text.strip())
        if not isinstance(update, dict):
            return scene
        return _apply_scene_updates(scene, update)

    def apply_character_feedback(self, character_payload: Dict[str, object], feedback_text: str) -> Dict[str, object]:
        if not feedback_text:
            return character_payload
        update = self.character_overrides.get(feedback_text.strip())
        if not isinstance(update, dict):
            return character_payload
        return _apply_character_updates(character_payload, update)


def _clone_scene(scene: SceneDescription) -> SceneDescription:
    return SceneDescription(
        world=scene.world,
        setting=scene.setting,
        mood=scene.mood,
        style=scene.style,
        nsfw_level=scene.nsfw_level,
        camera=scene.camera,
        characters=[CharacterRef(**asdict(ref)) for ref in scene.characters],
        extra_elements=list(scene.extra_elements),
    )


def _apply_scene_directives(scene: SceneDescription, feedback_text: str) -> SceneDescription:
    updated = _clone_scene(scene)
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
            setattr(updated, key, value)
        elif key in {"add element", "add elements", "elements", "extra", "extra_elements"}:
            for part in [v.strip() for v in value.split(",") if v.strip()]:
                if part not in updated.extra_elements:
                    updated.extra_elements.append(part)
        elif key.startswith("character"):
            _, _, remainder = key.partition(" ")
            target_slot = remainder.strip()
            if not target_slot:
                continue
            for character in updated.characters:
                if character.slot_id == target_slot:
                    if "role=" in value:
                        character.role = value.split("role=", 1)[1].strip()
                    elif "override_prompt_snippet=" in value:
                        character.override_prompt_snippet = value.split(
                            "override_prompt_snippet=", 1
                        )[1].strip()

    return updated


def _apply_scene_updates(scene: SceneDescription, update: Dict[str, object]) -> SceneDescription:
    updated = _clone_scene(scene)
    for key in ["world", "setting", "mood", "style", "camera", "nsfw_level"]:
        if key in update and isinstance(update[key], str):
            setattr(updated, key, update[key])
    extras = update.get("extra_elements")
    if isinstance(extras, list):
        updated.extra_elements = [value for value in extras if isinstance(value, str) and value.strip()]
    character_updates = update.get("characters")
    if isinstance(character_updates, list):
        for item in character_updates:
            if not isinstance(item, dict):
                continue
            slot_id = item.get("slot_id")
            if not isinstance(slot_id, str):
                continue
            for character in updated.characters:
                if character.slot_id != slot_id:
                    continue
                if "role" in item and isinstance(item.get("role"), str):
                    character.role = item["role"]
                if "override_prompt_snippet" in item and isinstance(item.get("override_prompt_snippet"), str):
                    character.override_prompt_snippet = item["override_prompt_snippet"]
                if "character_id" in item and isinstance(item.get("character_id"), str):
                    character.character_id = item["character_id"]
    return updated


def _clone_character_payload(payload: Dict[str, object]) -> Dict[str, object]:
    updated = dict(payload)
    for key in ["trigger_tokens", "anatomy_tags", "wardrobe", "reference_images"]:
        updated[key] = list(payload.get(key, []) or [])
    updated["metadata"] = dict(payload.get("metadata", {}) or {})
    return updated


def _apply_character_updates(payload: Dict[str, object], updates: Dict[str, object]) -> Dict[str, object]:
    updated = _clone_character_payload(payload)
    for key in ["description", "default_prompt_snippet", "trigger_token", "age", "name"]:
        if key in updates and isinstance(updates[key], str):
            updated[key] = updates[key]
    if "nsfw_allowed" in updates and isinstance(updates["nsfw_allowed"], bool):
        updated["nsfw_allowed"] = updates["nsfw_allowed"]
    if "trigger_tokens" in updates and isinstance(updates["trigger_tokens"], list):
        tokens = [token for token in updates["trigger_tokens"] if isinstance(token, str) and token.strip()]
        updated["trigger_tokens"] = tokens
        if tokens:
            updated["trigger_token"] = tokens[0]
    for list_key in ["anatomy_tags", "wardrobe", "reference_images"]:
        if list_key in updates and isinstance(updates[list_key], list):
            updated[list_key] = [
                value for value in updates[list_key] if isinstance(value, str) and value.strip()
            ]
    if "metadata" in updates and isinstance(updates["metadata"], dict):
        updated["metadata"].update({str(k): str(v) for k, v in updates["metadata"].items()})
    return updated


def _apply_character_directives(payload: Dict[str, object], feedback_text: str) -> Dict[str, object]:
    if not feedback_text or not feedback_text.strip():
        return payload

    directives = re.split(r"[\n;]+", feedback_text)
    updates: Dict[str, str] = {}
    for directive in directives:
        if ":" not in directive:
            continue
        key, value = directive.split(":", 1)
        updates[key.strip().lower()] = value.strip()

    updated = _clone_character_payload(payload)

    for key, value in updates.items():
        if key in {"description", "default_prompt_snippet", "trigger_token", "age", "name"}:
            updated[key] = value
        elif key in {"trigger_tokens", "triggers"}:
            additions = [v.strip() for v in value.split(",") if v.strip()]
            updated["trigger_tokens"] = additions
            if additions:
                updated["trigger_token"] = additions[0]
        elif key in {"nsfw", "nsfw_allowed"}:
            updated["nsfw_allowed"] = value.lower() in {"true", "1", "yes", "y", "allow"}
        elif key in {"tag", "anatomy_tag", "anatomy_tags", "tags"}:
            additions = [v.strip() for v in value.split(",") if v.strip()]
            for tag in additions:
                if tag not in updated["anatomy_tags"]:
                    updated["anatomy_tags"].append(tag)
        elif key in {"wardrobe"}:
            additions = [v.strip() for v in value.split(",") if v.strip()]
            for item in additions:
                if item not in updated["wardrobe"]:
                    updated["wardrobe"].append(item)
        elif key in {"reference_images", "reference_image"}:
            additions = [v.strip() for v in value.split(",") if v.strip()]
            for path in additions:
                if path not in updated["reference_images"]:
                    updated["reference_images"].append(path)
        elif key.startswith("metadata"):
            metadata_key = key.split(".", maxsplit=1)[1] if "." in key else "note"
            updated["metadata"][metadata_key] = value

    return updated


def _build_provider(name: str, settings: Dict[str, Any]) -> Optional[FeedbackProvider]:
    if name == "deterministic":
        return DeterministicFeedbackProvider(settings)
    if name == "preset":
        return PresetFeedbackProvider(settings)
    return None


def load_provider_config(config_path: Optional[Path] = None) -> ProviderConfig:
    path = Path(config_path) if config_path else Path(config_service.DEFAULT_CONFIG_PATH)
    loaded = config_service.load_config(str(path), env_prefix="", overrides=[])
    provider = config_service.deep_get(loaded.data, "llm.provider") or "deterministic"
    fallback_provider = config_service.deep_get(loaded.data, "llm.fallback_provider") or "deterministic"
    providers_raw = config_service.deep_get(loaded.data, "llm.providers") or {}
    providers = providers_raw if isinstance(providers_raw, dict) else {}
    providers = {
        str(name): settings if isinstance(settings, dict) else {}
        for name, settings in providers.items()
    }
    return ProviderConfig(
        provider=str(provider),
        fallback_provider=str(fallback_provider),
        providers=providers,
    )


def get_feedback_provider(
    config_path: Optional[Path] = None,
    provider_name: Optional[str] = None,
) -> Tuple[FeedbackProvider, FeedbackProvider]:
    config = load_provider_config(config_path)
    primary_name = provider_name or config.provider
    fallback_name = config.fallback_provider or "deterministic"

    fallback = _build_provider(fallback_name, config.providers.get(fallback_name, {}))
    if fallback is None:
        fallback = DeterministicFeedbackProvider()

    primary = _build_provider(primary_name, config.providers.get(primary_name, {}))
    if primary is None:
        primary = fallback

    return primary, fallback


def apply_scene_feedback(
    scene: SceneDescription,
    feedback_text: str,
    config_path: Optional[Path] = None,
    provider_name: Optional[str] = None,
) -> SceneDescription:
    if feedback_text is None:
        raise ValueError("feedback_text must be provided")
    if not isinstance(feedback_text, str):
        raise ValueError("feedback_text must be a string")

    provider, fallback = get_feedback_provider(config_path, provider_name)
    try:
        return provider.apply_scene_feedback(scene, feedback_text)
    except Exception:
        return fallback.apply_scene_feedback(scene, feedback_text)


def apply_character_feedback(
    character_payload: Dict[str, object],
    feedback_text: str,
    config_path: Optional[Path] = None,
    provider_name: Optional[str] = None,
) -> Dict[str, object]:
    if feedback_text is None:
        raise ValueError("feedback_text must be provided")
    if not isinstance(feedback_text, str):
        raise ValueError("feedback_text must be a string")

    provider, fallback = get_feedback_provider(config_path, provider_name)
    try:
        return provider.apply_character_feedback(character_payload, feedback_text)
    except Exception:
        return fallback.apply_character_feedback(character_payload, feedback_text)
