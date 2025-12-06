"""LLM abstraction layer for Prompt Builder operations.

The concrete implementation here is intentionally lightweight so it can be
swapped with a real LLM client later without modifying compiler callers.
"""

from __future__ import annotations

import re
from dataclasses import asdict
from typing import Dict, Iterable, List, Optional

from modules.character_studio.models import CharacterCard
from modules.character_studio.registry import CharacterCardRegistry

from .models import CharacterRef, LoRACall, PromptAssembly, SceneDescription


class SceneLLMAdapter:
    """Bridge SceneDescription payloads to prompt assemblies and feedback loops."""

    def __init__(self, card_registry: Optional[CharacterCardRegistry] = None) -> None:
        self.card_registry = card_registry or CharacterCardRegistry()

    def resolve_cards(self, characters: Iterable[CharacterRef]) -> Dict[str, CharacterCard]:
        """Resolve CharacterRefs into loaded Character Cards via the registry."""

        cards: Dict[str, CharacterCard] = {}
        for ref in characters:
            card = self.card_registry.find(ref.character_id)
            if card:
                cards[ref.character_id] = card
        return cards

    def synthesize_prompts(self, scene: SceneDescription, cards: Dict[str, CharacterCard]) -> PromptAssembly:
        """Produce a PromptAssembly for a scene using Character Card context."""

        positive_prompt: List[str] = []
        context_parts = [
            f"world: {scene.world}" if scene.world else None,
            f"setting: {scene.setting}" if scene.setting else None,
            f"mood: {scene.mood}" if scene.mood else None,
            f"style: {scene.style}" if scene.style else None,
            f"camera: {scene.camera}" if scene.camera else None,
        ]
        combined_context = "; ".join([part for part in context_parts if part])
        if combined_context:
            positive_prompt.append(combined_context)

        for character in scene.characters:
            snippet = self._character_prompt_snippet(character, cards.get(character.character_id))
            if snippet:
                positive_prompt.append(snippet)

        extras = [element.strip() for element in scene.extra_elements if element.strip()]
        if extras:
            positive_prompt.append("extras: " + ", ".join(extras))

        negative_prompt = ["low quality", "blurry"]
        if scene.nsfw_level in {"sfw", "safe"}:
            negative_prompt.append("nsfw")
        if any(card for card in cards.values() if not card.nsfw_allowed and scene.nsfw_level not in {None, "sfw", "safe"}):
            negative_prompt.append("explicit content")

        lora_calls = self._derive_lora_calls(cards, scene.characters)

        return PromptAssembly(
            positive_prompt=positive_prompt,
            negative_prompt=negative_prompt,
            lora_calls=lora_calls,
        )

    def apply_feedback(self, scene: SceneDescription, feedback_text: str) -> SceneDescription:
        """Refine a SceneDescription using natural language feedback.

        The current implementation applies structured heuristics so callers can
        rely on stable behavior until a full LLM client is introduced.
        """

        updated = SceneDescription(
            world=scene.world,
            setting=scene.setting,
            mood=scene.mood,
            style=scene.style,
            nsfw_level=scene.nsfw_level,
            camera=scene.camera,
            characters=[CharacterRef(**asdict(ref)) for ref in scene.characters],
            extra_elements=list(scene.extra_elements),
        )

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

    @staticmethod
    def _character_prompt_snippet(character: CharacterRef, card: Optional[CharacterCard]) -> str:
        override_snippet = character.override_prompt_snippet
        parts: List[str] = []
        if card:
            if card.trigger_token:
                parts.append(card.trigger_token)
            parts.extend(filter(None, [override_snippet or card.default_prompt_snippet, card.description]))
            if card.anatomy_tags:
                parts.append(", ".join(card.anatomy_tags))
        else:
            parts.append(character.character_id)
            if override_snippet:
                parts.append(override_snippet)
        if character.role:
            parts.append(f"role: {character.role}")
        return " | ".join([segment for segment in parts if segment])

    @staticmethod
    def _derive_lora_calls(cards: Dict[str, CharacterCard], characters: Iterable[CharacterRef]) -> List[LoRACall]:
        loras: List[LoRACall] = []
        for character in characters:
            card = cards.get(character.character_id)
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
