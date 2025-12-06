"""Service placeholders for the Prompt Builder module."""

from dataclasses import asdict
from typing import Dict, Optional

from . import compiler
from .models import PromptAssembly, SceneDescription


class PromptCompilerService:
    """Facade to compile scenes into prompt bundles.

    This stub keeps import-time side effects minimal so installers remain unaffected.
    """

    def compile_scene(self, scene: SceneDescription) -> PromptAssembly:
        scene_json = asdict(scene)
        compiled = compiler.build_prompt_from_scene(scene_json)
        return PromptAssembly(
            positive_prompt=compiled.get("positive_prompt") or [],
            negative_prompt=compiled.get("negative_prompt") or [],
            lora_calls=compiled.get("lora_calls") or [],
        )


class UIIntegrationHooks:
    """Hooks for UI layers to coordinate prompt compilation and delivery."""

    def preflight_scene(self, scene: SceneDescription) -> Optional[str]:
        """Validate a scene before compilation.

        Returns a string message when the scene is rejected; otherwise returns ``None``.
        """

        if not scene.characters and not scene.extra_elements:
            return "Provide at least one character or extra element before compiling."
        return None

    def publish_prompt(self, assembly: PromptAssembly) -> Dict:
        """Placeholder for shipping compiled prompts to a UI or launcher layer."""

        # Future implementations may write to disk, emit events, or call launcher scripts.
        return {
            "positive_prompt": assembly.positive_prompt,
            "negative_prompt": assembly.negative_prompt,
            "lora_calls": [asdict(lora) for lora in assembly.lora_calls],
        }
