"""Manifest validation and update helpers for curated model/LoRA metadata."""

from __future__ import annotations

from typing import Dict, List, Tuple
import re


MANIFEST_UPDATE_SCHEMA: Dict[str, object] = {
    "type": "object",
    "properties": {
        "tags": {"type": "array", "items": {"type": "string"}},
        "checksum": {"type": "string"},
        "metadata": {"type": "object"},
    },
    "additionalProperties": False,
}


def slugify(value: str) -> str:
    normalized = re.sub(r"[^a-zA-Z0-9]+", "-", value.strip().lower())
    return normalized.strip("-")


def normalize_manifest_entry(entry: Dict[str, object]) -> Tuple[Dict[str, object], List[str]]:
    normalized = dict(entry)
    normalized.setdefault("tags", [])
    normalized.setdefault("license", "")
    normalized.setdefault("notes", "")
    normalized.setdefault("version", "")
    normalized.setdefault("size_bytes", None)
    normalized.setdefault("checksum", "")
    normalized.setdefault("metadata", {})

    issues: List[str] = []
    name_value = normalized.get("name")
    if not isinstance(name_value, str) or not name_value.strip():
        issues.append("Manifest entries must include a name")

    entry_slug = normalized.get("slug") or (name_value and slugify(name_value))
    normalized["slug"] = entry_slug or ""
    if not normalized["slug"]:
        issues.append("Manifest entries must include a slug or valid name")

    if not normalized.get("url") and not normalized.get("filename"):
        issues.append("Entries should include a download url or filename")

    tags_value = normalized.get("tags")
    if not isinstance(tags_value, list) or not all(isinstance(tag, str) for tag in tags_value):
        issues.append("tags must be a list of strings")
        normalized["tags"] = []

    metadata_value = normalized.get("metadata")
    if metadata_value is not None and not isinstance(metadata_value, dict):
        issues.append("metadata must be an object")
        normalized["metadata"] = {}

    checksum_value = normalized.get("checksum")
    if checksum_value is not None and not isinstance(checksum_value, str):
        issues.append("checksum must be a string")
        normalized["checksum"] = ""

    size_value = normalized.get("size_bytes")
    if size_value is not None and not isinstance(size_value, int):
        issues.append("size_bytes must be an integer")
        normalized["size_bytes"] = None

    return normalized, issues


def validate_manifest_items(items: List[object], manifest_label: str) -> Tuple[List[Dict[str, object]], List[str]]:
    validated_items: List[Dict[str, object]] = []
    errors: List[str] = []

    for idx, item in enumerate(items):
        if not isinstance(item, dict):
            message = f"{manifest_label} items[{idx}] is not an object"
            errors.append(message)
            continue

        entry, issues = normalize_manifest_entry(item)
        entry["health"] = "ok" if not issues else "warning"
        entry["issues"] = issues
        if issues:
            errors.extend([f"{manifest_label} {entry.get('name') or entry.get('slug')}: {msg}" for msg in issues])

        validated_items.append(entry)

    return validated_items, errors


def apply_manifest_updates(entry: Dict[str, object], updates: Dict[str, object]) -> Dict[str, object]:
    updated = dict(entry)
    for field in ("tags", "checksum", "metadata"):
        if field in updates:
            updated[field] = updates[field]
    return updated
