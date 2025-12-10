"""Dataclasses representing available voice profiles."""
from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Dict, Optional


@dataclass
class VoiceProfile:
    name: str
    locale: str = "en-US"
    description: Optional[str] = None

    def to_dict(self) -> Dict[str, object]:
        payload = asdict(self)
        return payload
