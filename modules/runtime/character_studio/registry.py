"""Shared Character Card registry used across modules.

This registry centralizes disk lookups so Prompt Builder, dataset utilities,
and UI layers all resolve Character Cards through the same abstraction instead
of embedding file system knowledge.
"""

from __future__ import annotations

from pathlib import Path
from typing import Dict, Iterable, Optional

from . import models as character_models


class CharacterCardRegistry:
    """Load Character Cards from a common storage root with optional caching."""

    def __init__(self, storage_root: Optional[Path] = None) -> None:
        self.storage_root = Path(storage_root) if storage_root else character_models.CARD_STORAGE_ROOT
        self._cache: Dict[str, character_models.CharacterCard] = {}

    def get(self, card_id: str) -> character_models.CharacterCard:
        """Return a Character Card by id or raise FileNotFoundError."""

        cached = self._cache.get(card_id)
        if cached:
            return cached

        card_path = self.storage_root / card_id / "card.json"
        if not card_path.exists():
            raise FileNotFoundError(f"Character Card not found for id {card_id} at {card_path}")

        card = character_models.CharacterCard.load(card_id, path=card_path)
        self._cache[card_id] = card
        return card

    def find(self, card_id: str) -> Optional[character_models.CharacterCard]:
        """Return a Character Card when it exists, otherwise ``None``."""

        try:
            return self.get(card_id)
        except FileNotFoundError:
            return None

    def list_ids(self) -> Iterable[str]:
        """Enumerate known Character Card identifiers."""

        if not self.storage_root.exists():
            return []
        return [p.name for p in self.storage_root.iterdir() if (p / "card.json").exists()]
