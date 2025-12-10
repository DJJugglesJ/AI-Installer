"""Automatic speech recognition tool."""
from __future__ import annotations

from pathlib import Path

from modules.runtime.registry import ToolSpec, register_tool

register_tool(
    ToolSpec(
        id="asr",
        label="Speech Recognition",
        description="Generate transcripts from audio or video inputs.",
        kind="audio",
        entrypoint="modules.runtime.audio.asr.cli",
        cli_command=["bash", str(Path(__file__).resolve().parents[3] / "shell" / "run_asr.sh")],
        dependencies=(),
    )
)

__all__ = ["ToolSpec"]
