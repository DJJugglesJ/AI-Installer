"""Image-to-video tool."""
from __future__ import annotations

from pathlib import Path

from modules.runtime.registry import ToolSpec, register_tool

register_tool(
    ToolSpec(
        id="img2vid",
        label="Image to Video",
        description="Animate a source image into a short clip.",
        kind="video",
        entrypoint="modules.runtime.video.img2vid.cli",
        cli_command=["bash", str(Path(__file__).resolve().parents[3] / "shell" / "run_img2vid.sh")],
        dependencies=(),
    )
)

__all__ = ["ToolSpec"]
