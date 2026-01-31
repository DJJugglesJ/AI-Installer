"""Service helpers for txt2vid tasks."""
from __future__ import annotations

from modules.runtime.models.tasks import mark_failed, mark_running, mark_succeeded, new_task
from .core import generate_video
from .models import TextToVideoRequest


TASK_KIND = "txt2vid"


def _parse_int_field(value, field_name: str) -> int:
    if isinstance(value, bool):
        raise ValueError(f"{field_name} must be an integer")
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        stripped = value.strip()
        if stripped and stripped.lstrip("+-").isdigit():
            return int(stripped)
    raise ValueError(f"{field_name} must be an integer")


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
    duration_value = payload["duration"] if "duration" in payload else 4
    request = TextToVideoRequest(
        prompt=prompt,
        duration=_parse_int_field(duration_value, "duration"),
    )
    return run_txt2vid(request)
