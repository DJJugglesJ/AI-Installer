"""Shared Task dataclass used by runtime services."""
from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from datetime import datetime
from typing import Dict, Optional
from uuid import uuid4


@dataclass
class Task:
    id: str
    kind: str
    status: str
    created_at: str
    updated_at: str
    payload: Dict[str, object] = field(default_factory=dict)
    result: Optional[Dict[str, object]] = None
    error: Optional[str] = None


STATUSES = {"pending", "running", "completed", "failed"}


def _timestamp() -> str:
    return datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")


def new_task(kind: str, payload: Optional[Dict[str, object]] = None) -> Task:
    payload = payload or {}
    now = _timestamp()
    return Task(id=uuid4().hex[:12], kind=kind, status="pending", created_at=now, updated_at=now, payload=payload)


def mark_running(task: Task) -> Task:
    task.status = "running"
    task.updated_at = _timestamp()
    return task


def mark_succeeded(task: Task, result: Optional[Dict[str, object]] = None) -> Task:
    task.status = "completed"
    task.result = result or {}
    task.updated_at = _timestamp()
    return task


def mark_failed(task: Task, error: str) -> Task:
    task.status = "failed"
    task.error = error
    task.updated_at = _timestamp()
    return task


def serialize_task(task: Task) -> Dict[str, object]:
    return asdict(task)


def serialize_task_json(task: Task) -> str:
    return json.dumps(serialize_task(task), indent=2)


def task_from_dict(payload: Dict[str, object]) -> Task:
    return Task(
        id=str(payload.get("id", uuid4().hex[:12])),
        kind=str(payload.get("kind", "unknown")),
        status=str(payload.get("status", "pending")),
        created_at=str(payload.get("created_at", _timestamp())),
        updated_at=str(payload.get("updated_at", _timestamp())),
        payload=dict(payload.get("payload", {})),
        result=payload.get("result"),
        error=payload.get("error"),
    )
