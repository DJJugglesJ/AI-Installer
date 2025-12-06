"""Prompt Builder compiler stubs."""

from typing import Dict, List, Optional

# TODO: import shared Character Card models via a registry rather than duplicating schema definitions.


def build_prompt_from_scene(scene_json: Dict) -> Dict[str, Optional[List[str]]]:
    """Convert a structured SceneDescription into prompts and LoRA calls.

    Args:
        scene_json: SceneDescription payload.

    Returns:
        A dictionary with keys: positive_prompt, negative_prompt, lora_calls.
    """
    # TODO: load Character Cards through shared registry to enrich characters with trigger tokens and default snippets.
    # TODO: call LLM abstraction to compose positive and negative prompts.
    return {
        "positive_prompt": None,
        "negative_prompt": None,
        "lora_calls": None,
    }
