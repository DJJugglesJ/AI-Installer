"""Service helpers for txt2vid tasks."""
from __future__ import annotations

from modules.runtime.models.tasks import mark_failed, mark_running, mark_succeeded, new_task
from .core import generate_video
from .models import TextToVideoRequest


TASK_KIND = "txt2vid"


def run_txt2vid(request: TextToVideoRequest):
    task = new_task(TASK_KIND, payload=request.to_dict())
    mark_running(task)
    try:
        result = generate_video(request, task_id=task.id)
        mark_succeeded(task, result=result.to_dict())
    except Exception as exc:  # pragma: no cover - placeholder guard
        mark_failed(task, str(exc))
    return task


def run_txt2vid_from_payload(payload):
    prompt = payload.get("prompt")
    if not prompt:
        raise ValueError("prompt is required for txt2vid")
    request = TextToVideoRequest(prompt=prompt, duration=int(payload.get("duration", 4)))
    return run_txt2vid(request)
