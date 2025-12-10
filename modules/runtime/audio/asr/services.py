"""Service helpers for ASR tasks."""
from __future__ import annotations

from pathlib import Path

from modules.runtime.models.tasks import mark_failed, mark_running, mark_succeeded, new_task
from .core import transcribe
from .models import ASRRequest


TASK_KIND = "asr"


def run_asr(request: ASRRequest):
    task = new_task(TASK_KIND, payload=request.to_dict())
    mark_running(task)
    try:
        result = transcribe(request)
        mark_succeeded(task, result=result.to_dict())
    except Exception as exc:  # pragma: no cover - placeholder guard
        mark_failed(task, str(exc))
    return task


def run_asr_from_payload(payload):
    path_value = payload.get("source_path") or payload.get("path")
    if not path_value:
        raise ValueError("source_path is required for ASR")
    request = ASRRequest(source_path=Path(path_value), language=payload.get("language"))
    return run_asr(request)
