"""Text-to-speech runtime tool."""
from __future__ import annotations

from pathlib import Path

from modules.runtime.registry import ToolSpec, register_tool

register_tool(
    ToolSpec(
        id="tts",
        label="Text to Speech",
        description="Synthesize spoken audio from text payloads.",
        kind="audio",
        entrypoint="modules.runtime.audio.tts.cli",
        cli_command=["bash", str(Path(__file__).resolve().parents[3] / "shell" / "run_tts.sh")],
        dependencies=(),
    )
)

__all__ = ["ToolSpec"]
