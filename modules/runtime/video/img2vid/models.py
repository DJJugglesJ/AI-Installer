"""Dataclasses for image-to-video conversion."""
from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Dict, Optional


@dataclass
class ImageToVideoRequest:
    image_path: Path
    prompt: Optional[str] = None
    frames: int = 16

    def to_dict(self) -> Dict[str, object]:
        payload = asdict(self)
        payload["image_path"] = str(self.image_path)
        return payload


@dataclass
class ImageToVideoResult:
    video_path: Path
    frames: int

    def to_dict(self) -> Dict[str, object]:
        return {"video_path": str(self.video_path), "frames": self.frames}
