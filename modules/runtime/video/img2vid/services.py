"""Service helpers for img2vid tasks."""
from __future__ import annotations

from pathlib import Path

from modules.runtime.models.tasks import mark_failed, mark_running, mark_succeeded, new_task
from .core import generate_video
from .models import ImageToVideoRequest


TASK_KIND = "img2vid"


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


def run_img2vid(request: ImageToVideoRequest):
    task = new_task(TASK_KIND, payload=request.to_dict())
    mark_running(task)
    try:
        result = generate_video(request, task_id=task.id)
        mark_succeeded(task, result=result.to_dict())
    except Exception as exc:  # pragma: no cover - placeholder guard
        mark_failed(task, str(exc))
    return task


def run_img2vid_from_payload(payload):
    image_path_value = payload.get("image_path") or payload.get("path")
    if not image_path_value:
        raise ValueError("image_path is required for img2vid")
    frames_value = payload["frames"] if "frames" in payload else 16
    request = ImageToVideoRequest(
        image_path=Path(image_path_value),
        prompt=payload.get("prompt"),
        frames=_parse_int_field(frames_value, "frames"),
    )
    return run_img2vid(request)
