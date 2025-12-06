"""Minimal entry point to verify Prompt Builder imports without side effects."""

from dataclasses import asdict

from .models import CharacterRef, SceneDescription
from .services import PromptCompilerService, UIIntegrationHooks


def main() -> None:
    sample_scene = SceneDescription(
        world="demo world",
        setting="studio",
        characters=[CharacterRef(slot_id="hero", character_id="char_001", role="protagonist")],
        extra_elements=["soft lighting"],
    )

    hooks = UIIntegrationHooks()
    preflight_error = hooks.preflight_scene(sample_scene)
    if preflight_error:
        raise SystemExit(preflight_error)

    compiler = PromptCompilerService()
    assembly = compiler.compile_scene(sample_scene)
    payload = hooks.publish_prompt(assembly)
    print("Prompt Builder module loaded successfully. Sample payload:\n", payload)
    print("SceneDescription schema preview:\n", asdict(sample_scene))


if __name__ == "__main__":
    main()
