"""Dataclasses for text-to-speech requests and responses."""
from __future__ import annotations

from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Dict, Optional


@dataclass
class TextToSpeechRequest:
    text: str
    voice: Optional[str] = None
    metadata: Dict[str, str] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, object]:
        payload = asdict(self)
        payload["metadata"] = dict(self.metadata)
        return payload


@dataclass
class TextToSpeechResult:
    audio_path: Path
    voice: str

    def to_dict(self) -> Dict[str, object]:
        return {"audio_path": str(self.audio_path), "voice": self.voice}
