"""CLI entrypoint for Prompt Builder.

- Purpose: load a scene payload, optionally apply natural language feedback, and emit a prompt bundle.
- Assumptions: SceneDescription JSON is well-formed UTF-8 and UI hooks perform their own validation.
- Side effects: writes the latest prompt bundle to disk for launcher consumption via UIIntegrationHooks.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Iterable

from dataclasses import asdict

from . import compiler
from .models import CharacterRef, SceneDescription
from .services import PromptCompilerService, UIIntegrationHooks


def _load_scene(path: Path) -> SceneDescription:
    payload = json.loads(path.read_text(encoding="utf-8"))
    characters = [CharacterRef(**character) for character in payload.get("characters", [])]
    return SceneDescription(
        world=payload.get("world"),
        setting=payload.get("setting"),
        mood=payload.get("mood"),
        style=payload.get("style"),
        nsfw_level=payload.get("nsfw_level"),
        camera=payload.get("camera"),
        characters=characters,
        extra_elements=payload.get("extra_elements", []),
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Compile SceneDescription JSON into prompts")
    parser.add_argument("--scene", type=Path, required=True, help="Path to a SceneDescription JSON file")
    parser.add_argument("--feedback", help="Natural language feedback to refine the scene before compilation")
    return parser


def main(argv: Iterable[str] | None = None) -> None:
    parser = build_parser()
    args = parser.parse_args(list(argv) if argv is not None else None)

    scene = _load_scene(args.scene)
    if args.feedback:
        # Apply heuristic feedback before validation hooks so users see deterministic adjustments.
        scene_json = compiler.apply_feedback_to_scene(asdict(scene), args.feedback)
        scene = compiler.parse_scene_description(scene_json)

    hooks = UIIntegrationHooks()
    preflight_error = hooks.preflight_scene(scene)
    if preflight_error:
        raise SystemExit(preflight_error)

    try:
        compiler_service = PromptCompilerService()
        assembly = compiler_service.compile_scene(scene)
        # Persist the compiled bundle for downstream launchers while echoing JSON for CLI users.
        payload = hooks.publish_prompt(assembly)
    except ValueError as exc:
        raise SystemExit(str(exc)) from exc

    print(json.dumps(payload, indent=2))


def _load_scene_from_json(scene_json: dict) -> SceneDescription:
    characters = [CharacterRef(**character) for character in scene_json.get("characters", [])]
    return SceneDescription(
        world=scene_json.get("world"),
        setting=scene_json.get("setting"),
        mood=scene_json.get("mood"),
        style=scene_json.get("style"),
        nsfw_level=scene_json.get("nsfw_level"),
        camera=scene_json.get("camera"),
        characters=characters,
        extra_elements=scene_json.get("extra_elements", []),
    )


if __name__ == "__main__":
    main()
