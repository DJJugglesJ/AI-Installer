import json
import sys
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from modules.config_service import config_service
from modules.runtime.prompt_builder import llm_clients
from modules.runtime.prompt_builder.models import SceneDescription


def _write_config(tmp_path, data):
    path = tmp_path / "config.json"
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    return path


def test_provider_selection_uses_preset_overrides(tmp_path):
    config = deepcopy(config_service.DEFAULT_CONFIG)
    config["llm"]["provider"] = "preset"
    config["llm"]["fallback_provider"] = "deterministic"
    config["llm"]["providers"]["preset"]["scene_overrides"] = {
        "make it dramatic": {"mood": "dramatic", "extra_elements": ["rain"]}
    }
    config_path = _write_config(tmp_path, config)

    scene = SceneDescription(
        world="demo",
        setting="plaza",
        mood="calm",
        style=None,
        nsfw_level=None,
        camera=None,
        characters=[],
        extra_elements=[],
    )

    updated = llm_clients.apply_scene_feedback(scene, "make it dramatic", config_path=config_path)

    assert updated.mood == "dramatic"
    assert updated.extra_elements == ["rain"]


def test_provider_fallbacks_to_deterministic(tmp_path):
    config = deepcopy(config_service.DEFAULT_CONFIG)
    config["llm"]["provider"] = "missing"
    config["llm"]["fallback_provider"] = "deterministic"
    config_path = _write_config(tmp_path, config)

    scene = SceneDescription(
        world="demo",
        setting="plaza",
        mood="calm",
        style=None,
        nsfw_level=None,
        camera=None,
        characters=[],
        extra_elements=[],
    )

    updated = llm_clients.apply_scene_feedback(scene, "mood: tense", config_path=config_path)

    assert updated.mood == "tense"
