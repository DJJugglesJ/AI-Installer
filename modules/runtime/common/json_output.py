"""Standardized JSON output helpers for CLI entrypoints."""

from __future__ import annotations

import json
from typing import Any, Dict, Optional


def success(data: Any = None, metadata: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """Return a standardized success payload."""

    return {
        "data": data,
        "error": None,
        "metadata": metadata or {},
    }


def failure(
    message: str,
    *,
    context: Optional[Dict[str, Any]] = None,
    metadata: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """Return a standardized error payload."""

    return {
        "data": None,
        "error": {
            "message": message,
            "context": context or {},
        },
        "metadata": metadata or {},
    }


def to_json(payload: Dict[str, Any]) -> str:
    """Serialize payloads for CLI output."""

    return json.dumps(payload, indent=2)
