"""Service helpers for voice profiles."""
from __future__ import annotations

from modules.runtime.models.tasks import mark_running, mark_succeeded, new_task
from .core import default_profiles


TASK_KIND = "voice_profiles"


def list_voice_profiles():
    task = new_task(TASK_KIND, payload={})
    mark_running(task)
    profiles = [profile.to_dict() for profile in default_profiles()]
    mark_succeeded(task, result={"profiles": profiles})
    return task
