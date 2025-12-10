"""Placeholder txt2vid logic."""
from __future__ import annotations

from pathlib import Path
from typing import Optional

from .models import TextToVideoRequest, TextToVideoResult


OUTPUT_DIR = Path.home() / ".cache/aihub/video/txt2vid"


def generate_video(request: TextToVideoRequest, task_id: Optional[str] = None) -> TextToVideoResult:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    video_name = f"{task_id or 'txt2vid-job'}.mp4"
    video_path = OUTPUT_DIR / video_name
    video_path.write_text(
        "\n".join(
            [
                "AI Hub txt2vid placeholder",
                f"prompt={request.prompt}",
                f"duration={request.duration}s",
            ]
        ),
        encoding="utf-8",
    )
    return TextToVideoResult(video_path=video_path, duration=request.duration)
