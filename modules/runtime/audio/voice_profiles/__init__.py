"""Voice profile metadata tool."""
from __future__ import annotations

from modules.runtime.registry import ToolSpec, register_tool

register_tool(
    ToolSpec(
        id="voice_profiles",
        label="Voice Profiles",
        description="List placeholder voice profiles for TTS routing.",
        kind="audio",
        entrypoint="modules.runtime.audio.voice_profiles.cli",
        cli_command=["python", "-m", "modules.runtime.audio.voice_profiles.cli"],
        dependencies=(),
    )
)

__all__ = ["ToolSpec"]
