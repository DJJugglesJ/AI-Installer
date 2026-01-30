"""Feedback utilities for Prompt Builder scenes.

- Purpose: apply structured natural-language feedback to SceneDescription objects.
- Assumptions: callers pass validated SceneDescription payloads.
- Side effects: none; functions return updated copies only.
"""

from __future__ import annotations

from .llm import SceneLLMAdapter
from .models import SceneDescription, validate_scene


def apply_feedback_to_scene(scene: SceneDescription, feedback_text: str) -> SceneDescription:
    """Apply feedback to a SceneDescription and return the updated scene."""

    if feedback_text is None:
        raise ValueError("feedback_text must be provided")
    if not isinstance(feedback_text, str):
        raise ValueError("feedback_text must be a string")

    validate_scene(scene)
    adapter = SceneLLMAdapter()
    updated_scene = adapter.apply_feedback(scene, feedback_text)
    validate_scene(updated_scene)
    return updated_scene
