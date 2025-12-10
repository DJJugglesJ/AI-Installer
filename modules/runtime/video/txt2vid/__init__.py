"""Text-to-video tool."""
from __future__ import annotations

from pathlib import Path

from modules.runtime.registry import ToolSpec, register_tool

register_tool(
    ToolSpec(
        id="txt2vid",
        label="Text to Video",
        description="Generate a short clip from a text prompt.",
        kind="video",
        entrypoint="modules.runtime.video.txt2vid.cli",
        cli_command=["bash", str(Path(__file__).resolve().parents[3] / "shell" / "run_txt2vid.sh")],
        dependencies=(),
    )
)

__all__ = ["ToolSpec"]
