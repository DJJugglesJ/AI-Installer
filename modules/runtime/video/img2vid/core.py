"""Placeholder img2vid logic."""
from __future__ import annotations

from pathlib import Path
from typing import Optional

from .models import ImageToVideoRequest, ImageToVideoResult


OUTPUT_DIR = Path.home() / ".cache/aihub/video/img2vid"


def generate_video(request: ImageToVideoRequest, task_id: Optional[str] = None) -> ImageToVideoResult:
    if not request.image_path.exists():
        raise FileNotFoundError(f"Image not found: {request.image_path}")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    video_name = f"{task_id or request.image_path.stem}.mp4"
    video_path = OUTPUT_DIR / video_name
    video_path.write_text(
        "\n".join(
            [
                "AI Hub img2vid placeholder",
                f"source={request.image_path}",
                f"prompt={request.prompt or ''}",
                f"frames={request.frames}",
            ]
        ),
        encoding="utf-8",
    )
    return ImageToVideoResult(video_path=video_path, frames=request.frames)
