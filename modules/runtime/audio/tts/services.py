"""Service helpers for TTS tasks."""
from __future__ import annotations

from modules.runtime.models.tasks import mark_failed, mark_running, mark_succeeded, new_task
from .core import synthesize_speech
from .models import TextToSpeechRequest


TASK_KIND = "tts"


def run_text_to_speech(request: TextToSpeechRequest):
    task = new_task(TASK_KIND, payload=request.to_dict())
    mark_running(task)
    try:
        result = synthesize_speech(request, task_id=task.id)
        mark_succeeded(task, result=result.to_dict())
    except Exception as exc:  # pragma: no cover - placeholder guard
        mark_failed(task, str(exc))
    return task


def run_text_to_speech_from_payload(payload):
    request = TextToSpeechRequest(
        text=str(payload.get("text", "")),
        voice=payload.get("voice") or None,
        metadata=payload.get("metadata") or {},
    )
    if not request.text:
        raise ValueError("Text is required for TTS")
    return run_text_to_speech(request)
