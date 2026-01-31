"""LLM abstraction layer for Prompt Builder operations.

- Purpose: derive prompts and LoRA calls from scene payloads while handling feedback heuristics.
- Assumptions: Character Card metadata is available via the registry and callers pass validated scenes.
- Side effects: none beyond deterministic prompt assembly; file writes occur in service hooks.
"""

from __future__ import annotations

from typing import Dict, Iterable, List, Optional

from modules.runtime.character_studio.models import CharacterCard
from modules.runtime.character_studio.registry import CharacterCardRegistry

from .models import CharacterRef, LoRACall, PromptAssembly, SceneDescription
from . import llm_clients


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
        # Aggregate high-level context first so downstream strings have predictable ordering.
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
        # Respect NSFW boundaries declared by the scene and underlying cards to avoid unsafe mixes.
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

        return llm_clients.DeterministicFeedbackProvider().apply_scene_feedback(scene, feedback_text)

    @staticmethod
    def _character_prompt_snippet(character: CharacterRef, card: Optional[CharacterCard]) -> str:
        override_snippet = character.override_prompt_snippet
        parts: List[str] = []
        if card:
            trigger_tokens = []
            if card.trigger_tokens:
                trigger_tokens.extend(card.trigger_tokens)
            if card.trigger_token and card.trigger_token not in trigger_tokens:
                trigger_tokens.insert(0, card.trigger_token)
            if trigger_tokens:
                parts.append(" ".join(trigger_tokens))
            parts.extend(filter(None, [override_snippet or card.default_prompt_snippet, card.description]))
            if card.anatomy_tags:
                parts.append(", ".join(card.anatomy_tags))
            if card.wardrobe:
                parts.append("wardrobe: " + ", ".join(card.wardrobe))
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
