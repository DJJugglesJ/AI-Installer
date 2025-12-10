"""Core text-to-speech routines (placeholder implementation)."""
from __future__ import annotations

from pathlib import Path
from typing import Optional

from .models import TextToSpeechRequest, TextToSpeechResult


OUTPUT_DIR = Path.home() / ".cache/aihub/audio/tts"


def synthesize_speech(request: TextToSpeechRequest, task_id: Optional[str] = None) -> TextToSpeechResult:
    """Simulate speech synthesis by writing request details to a cache file."""

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_name = f"{task_id or 'tts-job'}.txt"
    output_path = OUTPUT_DIR / output_name
    voice = request.voice or "default"
    output_path.write_text(
        "\n".join(
            [
                "AI Hub TTS placeholder output",
                f"voice={voice}",
                f"text={request.text}",
            ]
        ),
        encoding="utf-8",
    )
    return TextToSpeechResult(audio_path=output_path, voice=voice)
