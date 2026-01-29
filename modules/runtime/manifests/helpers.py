"""Helpers for reading, validating, and updating curated manifests."""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

from modules.config_service import config_service


MANIFEST_UPDATE_SCHEMA: Dict[str, object] = {
    "type": "object",
    "properties": {
        "tags": {"type": "array", "items": {"type": "string"}},
        "notes": {"type": "string"},
    },
    "additionalProperties": False,
}


@dataclass(frozen=True)
class ChecksumDetails:
    status: str
    local_checksum: str = ""
    file_path: str = ""


def slugify(value: str) -> str:
    normalized = "".join([ch.lower() if ch.isalnum() else "-" for ch in value.strip()])
    return "-".join(filter(None, normalized.split("-")))


def _default_install_dirs() -> Dict[str, Path]:
    return {
        "models": Path.home() / "ai-hub" / "models",
        "loras": Path.home() / "AI" / "LoRAs",
    }


def _resolve_install_dir(manifest_type: str, install_dirs: Optional[Dict[str, Path]]) -> Path:
    resolved = (install_dirs or {}).get(manifest_type)
    if resolved is not None:
        return resolved
    return _default_install_dirs().get(manifest_type, Path.home())


def _compute_sha256(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest().upper()


def _checksum_details(
    entry: Dict[str, object],
    manifest_type: str,
    install_dirs: Optional[Dict[str, Path]] = None,
    validate_checksum: bool = False,
) -> ChecksumDetails:
    checksum = str(entry.get("checksum") or "").strip()
    filename = str(entry.get("filename") or "").strip()
    install_dir = _resolve_install_dir(manifest_type, install_dirs)
    if not filename:
        return ChecksumDetails(status="no-filename")

    file_path = install_dir / filename
    if not file_path.exists():
        return ChecksumDetails(status="missing", file_path=str(file_path))

    if not checksum:
        return ChecksumDetails(status="no-checksum", file_path=str(file_path))

    if not validate_checksum:
        return ChecksumDetails(status="unchecked", file_path=str(file_path))

    local_checksum = _compute_sha256(file_path)
    status = "verified" if local_checksum.upper() == checksum.upper() else "mismatch"
    return ChecksumDetails(status=status, local_checksum=local_checksum, file_path=str(file_path))


def _normalize_tags(tags: Iterable[object]) -> List[str]:
    normalized = []
    for tag in tags:
        if not isinstance(tag, str):
            continue
        cleaned = tag.strip()
        if cleaned and cleaned not in normalized:
            normalized.append(cleaned)
    return normalized


def _normalize_item(entry: Dict[str, object]) -> Dict[str, object]:
    normalized = dict(entry)
    normalized.setdefault("tags", [])
    normalized.setdefault("license", "")
    normalized.setdefault("notes", "")
    normalized.setdefault("version", "")
    normalized.setdefault("size_bytes", None)
    normalized.setdefault("checksum", "")
    name_value = normalized.get("name")
    slug_value = normalized.get("slug") or (name_value and slugify(str(name_value)))
    normalized["slug"] = slug_value or ""
    if isinstance(normalized.get("tags"), list):
        normalized["tags"] = _normalize_tags(normalized["tags"])
    else:
        normalized["tags"] = []
    if not isinstance(normalized.get("notes"), str):
        normalized["notes"] = str(normalized.get("notes") or "")
    return normalized


def _annotate_items(
    items: List[Dict[str, object]],
    manifest_type: str,
    install_dirs: Optional[Dict[str, Path]] = None,
    validate_checksums: bool = False,
) -> List[Dict[str, object]]:
    annotated: List[Dict[str, object]] = []
    for item in items:
        normalized = _normalize_item(item)
        details = _checksum_details(normalized, manifest_type, install_dirs, validate_checksums)
        normalized["checksum_status"] = details.status
        normalized["checksum_local"] = details.local_checksum
        normalized["file_path"] = details.file_path
        annotated.append(normalized)
    return annotated


def load_manifest_payload(
    manifest_dir: Path,
    manifest_type: str,
    *,
    install_dirs: Optional[Dict[str, Path]] = None,
    validate_checksums: bool = False,
) -> Dict[str, object]:
    manifest_path = manifest_dir / f"{manifest_type}.json"
    base_payload = {"source": None, "items": [], "errors": [], "has_errors": False, "type": manifest_type}
    if not manifest_path.exists():
        message = f"Manifest {manifest_path.name} not found"
        return {**base_payload, "errors": [message], "has_errors": True}

    try:
        payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        message = f"Failed to parse {manifest_path.name}: {exc}"
        return {**base_payload, "errors": [message], "has_errors": True}

    if not isinstance(payload, dict):
        message = f"Manifest {manifest_path.name} must be a JSON object"
        return {**base_payload, "errors": [message], "has_errors": True}

    source = payload.get("source")
    items = payload.get("items", [])
    if not isinstance(items, list):
        message = f"Manifest {manifest_path.name} items must be a list"
        return {**base_payload, "source": source, "errors": [message], "has_errors": True}

    errors: List[str] = []
    validated_items: List[Dict[str, object]] = []
    for idx, item in enumerate(items):
        if not isinstance(item, dict):
            errors.append(f"{manifest_path.name} items[{idx}] is not an object")
            continue

        entry = _normalize_item(item)
        issues: List[str] = []
        name_value = entry.get("name")
        if not isinstance(name_value, str) or not name_value.strip():
            issues.append("Manifest entries must include a name")
        if not entry.get("slug"):
            issues.append("Manifest entries must include a slug or valid name")
        if not entry.get("url") and not entry.get("filename"):
            issues.append("Entries should include a download url or filename")
        if not isinstance(entry.get("tags"), list):
            issues.append("tags must be a list")
            entry["tags"] = []

        entry["health"] = "ok" if not issues else "warning"
        entry["issues"] = issues
        if issues:
            errors.extend([f"{manifest_path.name} {entry['name'] or entry['slug']}: {msg}" for msg in issues])
        validated_items.append(entry)

    annotated = _annotate_items(validated_items, manifest_type, install_dirs, validate_checksums)
    return {
        "source": source,
        "items": annotated,
        "errors": errors,
        "has_errors": bool(errors),
        "type": manifest_type,
    }


def update_manifest_item(
    manifest_dir: Path,
    manifest_type: str,
    item_id: str,
    updates: Dict[str, object],
) -> Dict[str, object]:
    errors = config_service.validate_against_schema(updates, MANIFEST_UPDATE_SCHEMA)
    if errors:
        raise ValueError("; ".join(errors))

    manifest_path = manifest_dir / f"{manifest_type}.json"
    payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"Manifest {manifest_type} is invalid")

    items = payload.get("items")
    if not isinstance(items, list):
        raise ValueError(f"Manifest {manifest_type} items must be a list")

    normalized_id = slugify(item_id)
    updated_item: Optional[Dict[str, object]] = None
    for entry in items:
        if not isinstance(entry, dict):
            continue
        slug_value = slugify(str(entry.get("slug") or entry.get("name") or ""))
        if slug_value != normalized_id:
            continue
        if "tags" in updates:
            entry["tags"] = _normalize_tags(updates.get("tags", []))
        if "notes" in updates:
            entry["notes"] = str(updates.get("notes") or "")
        updated_item = entry
        break

    if updated_item is None:
        raise ValueError(f"Manifest item '{item_id}' not found in {manifest_type}")

    manifest_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return _normalize_item(updated_item)


def validate_manifest_checksums(
    manifest_dir: Path,
    manifest_type: Optional[str] = None,
    install_dirs: Optional[Dict[str, Path]] = None,
) -> Dict[str, object]:
    manifest_types = [manifest_type] if manifest_type else ["models", "loras"]
    results: Dict[str, object] = {"items": {}, "summary": {}}

    for entry_type in manifest_types:
        payload = load_manifest_payload(
            manifest_dir,
            entry_type,
            install_dirs=install_dirs,
            validate_checksums=True,
        )
        items = payload.get("items", [])
        summary = {
            "total": len(items),
            "verified": sum(1 for item in items if item.get("checksum_status") == "verified"),
            "mismatch": sum(1 for item in items if item.get("checksum_status") == "mismatch"),
            "missing": sum(1 for item in items if item.get("checksum_status") == "missing"),
            "unchecked": sum(1 for item in items if item.get("checksum_status") == "unchecked"),
        }
        results["items"][entry_type] = items
        results["summary"][entry_type] = summary

    return results
