"""Prompt Builder history and favorites storage helpers.

- Purpose: persist compiled prompt assemblies for UI recall and reuse.
- Assumptions: payloads are already validated by Prompt Builder compilers.
- Side effects: reads/writes JSON history files under the prompt builder cache.
"""

from __future__ import annotations

import json
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional


DEFAULT_HISTORY_PATH = Path.home() / ".cache/aihub/prompt_builder/prompt_history.json"


@dataclass
class PromptHistoryEntry:
    id: str
    created_at: str
    scene: Dict[str, object]
    assembly: Dict[str, object]
    favorite: bool = False
    notes: Optional[str] = None
    metadata: Dict[str, object] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, object]:
        return asdict(self)


class PromptHistoryStore:
    """File-backed store for prompt history entries and favorites."""

    def __init__(self, history_path: Optional[Path] = None, limit: int = 50) -> None:
        self.history_path = Path(history_path) if history_path else DEFAULT_HISTORY_PATH
        self.limit = limit
        self.history_path.parent.mkdir(parents=True, exist_ok=True)

    def list_entries(self) -> List[PromptHistoryEntry]:
        if not self.history_path.exists():
            return []
        payload = json.loads(self.history_path.read_text(encoding="utf-8"))
        if not isinstance(payload, list):
            return []
        entries: List[PromptHistoryEntry] = []
        for raw in payload:
            if not isinstance(raw, dict):
                continue
            entry = PromptHistoryEntry(
                id=str(raw.get("id")),
                created_at=str(raw.get("created_at")),
                scene=dict(raw.get("scene", {}) or {}),
                assembly=dict(raw.get("assembly", {}) or {}),
                favorite=bool(raw.get("favorite", False)),
                notes=raw.get("notes"),
                metadata=dict(raw.get("metadata", {}) or {}),
            )
            entries.append(entry)
        return entries

    def save_entries(self, entries: List[PromptHistoryEntry]) -> None:
        serialized = [entry.to_dict() for entry in entries[: self.limit]]
        self.history_path.write_text(json.dumps(serialized, indent=2), encoding="utf-8")

    def add_entry(
        self,
        scene: Dict[str, object],
        assembly: Dict[str, object],
        *,
        favorite: bool = False,
        notes: Optional[str] = None,
        metadata: Optional[Dict[str, object]] = None,
    ) -> PromptHistoryEntry:
        entry = PromptHistoryEntry(
            id=str(uuid.uuid4()),
            created_at=datetime.utcnow().isoformat() + "Z",
            scene=scene,
            assembly=assembly,
            favorite=favorite,
            notes=notes,
            metadata=metadata or {},
        )
        entries = self.list_entries()
        entries.insert(0, entry)
        self.save_entries(entries)
        return entry

    def set_favorite(self, entry_id: str, favorite: bool) -> PromptHistoryEntry:
        entries = self.list_entries()
        for idx, entry in enumerate(entries):
            if entry.id == entry_id:
                entries[idx].favorite = favorite
                self.save_entries(entries)
                return entries[idx]
        raise ValueError(f"History entry {entry_id} not found")

    def list_favorites(self) -> List[PromptHistoryEntry]:
        return [entry for entry in self.list_entries() if entry.favorite]
