"""Dataclasses for text-to-video generation."""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Dict


@dataclass
class TextToVideoRequest:
    prompt: str
    duration: int = 4

    def to_dict(self) -> Dict[str, object]:
        return {"prompt": self.prompt, "duration": self.duration}


@dataclass
class TextToVideoResult:
    video_path: Path
    duration: int

    def to_dict(self) -> Dict[str, object]:
        return {"video_path": str(self.video_path), "duration": self.duration}
