"""Lightweight registry for runtime tools surfaced through the launcher and UI."""
from __future__ import annotations

import importlib.util
import logging
from dataclasses import asdict, dataclass, field
from typing import Dict, Iterable, List, Optional

logger = logging.getLogger(__name__)


@dataclass
class ToolSpec:
    """Describe a runtime tool exposed through the registry."""

    id: str
    label: str
    description: str
    kind: str
    entrypoint: str
    cli_command: Optional[List[str]] = None
    dependencies: Iterable[str] = field(default_factory=tuple)
    available: bool = True
    availability_error: Optional[str] = None

    def to_dict(self) -> Dict[str, object]:
        payload = asdict(self)
        payload["dependencies"] = list(self.dependencies)
        return payload


tools: Dict[str, ToolSpec] = {}


def _dependencies_missing(dependencies: Iterable[str]) -> List[str]:
    missing: List[str] = []
    for dependency in dependencies:
        if not dependency:
            continue
        if importlib.util.find_spec(dependency) is None:
            missing.append(dependency)
    return missing


def register_tool(spec: ToolSpec) -> ToolSpec:
    """Register a tool while gracefully handling missing dependencies."""

    try:
        missing = _dependencies_missing(spec.dependencies)
        if missing:
            spec.available = False
            spec.availability_error = f"Missing dependencies: {', '.join(sorted(set(missing)))}"
        tools[spec.id] = spec
    except Exception as exc:  # pragma: no cover - defensive guard
        spec.available = False
        spec.availability_error = f"Registration failed: {exc}"
        tools[spec.id] = spec
        logger.warning("Failed to register tool %s: %s", spec.id, exc)
    return spec


def list_tools(kind: Optional[str] = None, available_only: bool = False) -> List[ToolSpec]:
    registered = list(tools.values())
    if kind:
        registered = [tool for tool in registered if tool.kind == kind]
    if available_only:
        registered = [tool for tool in registered if tool.available]
    return registered


def get_tool(tool_id: str) -> Optional[ToolSpec]:
    return tools.get(tool_id)


def reset_registry() -> None:
    tools.clear()


def load_default_tools() -> None:
    """Import tool packages to populate the registry."""

    # Imports are intentionally local to avoid import cycles during bootstrap.
    from modules.runtime.audio import asr as audio_asr  # noqa: F401
    from modules.runtime.audio import tts as audio_tts  # noqa: F401
    from modules.runtime.audio import voice_profiles as audio_voice_profiles  # noqa: F401
    from modules.runtime.video import img2vid as video_img2vid  # noqa: F401
    from modules.runtime.video import txt2vid as video_txt2vid  # noqa: F401

    _ = (audio_asr, audio_tts, audio_voice_profiles, video_img2vid, video_txt2vid)
