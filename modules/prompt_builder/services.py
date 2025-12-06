"""Service placeholders for the Prompt Builder module.

- Purpose: provide thin wrappers that compile scenes and persist prompt bundles for launcher use.
- Assumptions: callers pass validated SceneDescription objects and bundle path is writable.
- Side effects: writes compiled prompt bundles and timestamps to disk for downstream consumers.
"""

from dataclasses import asdict
from datetime import datetime
import json
import os
from pathlib import Path
from typing import Dict, Optional

from . import compiler
from .models import PromptAssembly, SceneDescription


_DEFAULT_CACHE = Path.home() / ".cache/aihub/prompt_builder/prompt_bundle.json"
DEFAULT_BUNDLE_PATH = Path(os.path.expanduser(os.environ.get("PROMPT_BUNDLE_PATH", str(_DEFAULT_CACHE))))


class PromptCompilerService:
    """Facade to compile scenes into prompt bundles.

    This stub keeps import-time side effects minimal so installers remain unaffected.
    """

    def compile_scene(self, scene: SceneDescription) -> PromptAssembly:
        scene_json = asdict(scene)
        return compiler.build_prompt_from_scene(scene_json)


class UIIntegrationHooks:
    """Hooks for UI layers to coordinate prompt compilation and delivery.

    When a prompt is published the compiled bundle is written to disk so launcher
    scripts can ingest the latest prompt payload without additional RPC plumbing.
    """

    def __init__(self, bundle_path: Optional[Path] = None) -> None:
        self.bundle_path = Path(bundle_path) if bundle_path else DEFAULT_BUNDLE_PATH

    def preflight_scene(self, scene: SceneDescription) -> Optional[str]:
        """Validate a scene before compilation.

        Returns a string message when the scene is rejected; otherwise returns ``None``.
        """

        if not scene.characters and not scene.extra_elements:
            return "Provide at least one character or extra element before compiling."
        return None

    def publish_prompt(self, assembly: PromptAssembly) -> Dict:
        """Persist compiled prompts for consumption by launchers and UIs."""

        payload = assembly.to_payload()
        return self._write_bundle(payload)

    def _write_bundle(self, payload: Dict) -> Dict:
        """Write the prompt bundle to disk for launcher consumption."""

        bundle_dir = self.bundle_path.parent
        bundle_dir.mkdir(parents=True, exist_ok=True)

        # Persist metadata alongside prompts so shell launchers can determine freshness without parsing logs.
        enriched_payload = {
            **payload,
            "compiled_at": datetime.utcnow().isoformat() + "Z",
            "bundle_path": str(self.bundle_path),
        }
        self.bundle_path.write_text(json.dumps(enriched_payload, indent=2), encoding="utf-8")
        return enriched_payload
