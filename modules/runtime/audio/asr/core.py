"""Placeholder ASR implementation."""
from __future__ import annotations

from pathlib import Path

from .models import ASRRequest, ASRResult


def transcribe(request: ASRRequest) -> ASRResult:
    if not request.source_path.exists():
        raise FileNotFoundError(f"Source not found: {request.source_path}")

    snippet = request.source_path.stem.replace("_", " ")
    transcript = f"Transcript for {snippet}"
    return ASRResult(transcript=transcript, source_path=request.source_path, language=request.language)
