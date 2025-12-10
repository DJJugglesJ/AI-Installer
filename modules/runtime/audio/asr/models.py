"""Dataclasses for automatic speech recognition requests and responses."""
from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Dict, Optional


@dataclass
class ASRRequest:
    source_path: Path
    language: Optional[str] = None

    def to_dict(self) -> Dict[str, object]:
        return {"source_path": str(self.source_path), "language": self.language}


@dataclass
class ASRResult:
    transcript: str
    source_path: Path
    language: Optional[str] = None

    def to_dict(self) -> Dict[str, object]:
        payload = asdict(self)
        payload["source_path"] = str(self.source_path)
        return payload
