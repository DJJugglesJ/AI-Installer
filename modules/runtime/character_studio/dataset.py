"""Dataset management helpers for Character Studio.

- Purpose: structure character datasets, enforce NSFW boundaries, and generate caption scaffolding.
- Assumptions: Character Cards exist on disk and dataset directories are writable.
- Side effects: creates dataset folders, copies user images, and writes caption metadata files.
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path
from typing import Iterable, List

from .models import CARD_STORAGE_ROOT, CharacterCard

DATASET_ROOT = Path(__file__).resolve().parent / "datasets"
DATASET_ROOT.mkdir(exist_ok=True)

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}


def _load_card(character_id: str) -> CharacterCard:
    card_path = CARD_STORAGE_ROOT / character_id / "card.json"
    if not card_path.exists():
        raise FileNotFoundError(f"Character Card not found for id {character_id} at {card_path}")
    return CharacterCard.load(character_id, path=card_path)


def _character_dataset_dir(character_id: str) -> Path:
    return DATASET_ROOT / "characters" / character_id


def get_character_dataset_dir(character_id: str) -> Path:
    """Public accessor for the dataset root for a character."""

    return _character_dataset_dir(character_id)


def get_subset_dir(character_id: str, subset_name: str) -> Path:
    """Return the absolute path to a dataset subset for a character."""

    subset_path = Path(subset_name.strip("/")) if subset_name else Path("base")
    return _character_dataset_dir(character_id) / subset_path


def _subset_is_nsfw(subset_name: str) -> bool:
    return "nsfw" in {part.lower() for part in Path(subset_name).parts}


def _persist_dataset_metadata(card: CharacterCard) -> Path:
    dataset_dir = _character_dataset_dir(card.id)
    dataset_dir.mkdir(parents=True, exist_ok=True)
    metadata = {
        "character_id": card.id,
        "name": card.name,
        "nsfw_allowed": card.nsfw_allowed,
        "trigger_token": card.trigger_token,
        "default_prompt_snippet": card.default_prompt_snippet,
        "anatomy_tags": card.anatomy_tags,
    }
    metadata_path = dataset_dir / "dataset.json"
    metadata_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    return metadata_path


def create_dataset_structure(character_id: str) -> None:
    """Create base and NSFW dataset directories for a character."""

    card = _load_card(character_id)
    dataset_dir = _character_dataset_dir(character_id)
    base_dir = dataset_dir / "base"
    base_dir.mkdir(parents=True, exist_ok=True)

    if card.nsfw_allowed:
        (dataset_dir / "nsfw").mkdir(parents=True, exist_ok=True)

    metadata_path = _persist_dataset_metadata(card)
    print(f"Initialized dataset for {character_id} at {dataset_dir} (metadata: {metadata_path})")


def add_images_to_dataset(character_id: str, images: Iterable[str], subset_name: str) -> List[str]:
    """Add selected images to a dataset subset and return stored paths."""

    card = _load_card(character_id)
    if _subset_is_nsfw(subset_name) and not card.nsfw_allowed:
        raise PermissionError("NSFW dataset subsets are not allowed for this character")

    target_dir = get_subset_dir(character_id, subset_name)
    target_dir.mkdir(parents=True, exist_ok=True)

    stored: List[str] = []
    for image_path_str in images:
        image_path = Path(image_path_str).expanduser().resolve()
        if not image_path.exists():
            raise FileNotFoundError(f"Image not found: {image_path}")
        # Avoid accidental overwrite by suffixing duplicates inside the chosen subset.
        destination = target_dir / image_path.name
        suffix_counter = 1
        while destination.exists():
            destination = target_dir / f"{image_path.stem}_{suffix_counter}{image_path.suffix}"
            suffix_counter += 1
        shutil.copy(image_path, destination)
        stored.append(str(destination))

    return stored


def list_subset_images(character_id: str, subset_name: str) -> List[Path]:
    subset_dir = get_subset_dir(character_id, subset_name)
    if not subset_dir.exists():
        return []
    return sorted(
        [p for p in subset_dir.iterdir() if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS]
    )


def generate_captions_for_dataset(character_id: str, subset_name: str) -> List[str]:
    """Generate training captions based on Character Card defaults and subset context."""

    card = _load_card(character_id)
    if _subset_is_nsfw(subset_name) and not card.nsfw_allowed:
        raise PermissionError("NSFW dataset subsets are not allowed for this character")

    subset_dir = get_subset_dir(character_id, subset_name)
    subset_dir.mkdir(parents=True, exist_ok=True)
    captions: List[str] = []
    subset_tags = [part.replace("_", " ") for part in Path(subset_name).parts if part.lower() not in {"base", "nsfw"}]

    for image_path in list_subset_images(character_id, subset_name):
        caption_parts: List[str] = []
        if card.trigger_token:
            caption_parts.append(card.trigger_token)
        caption_parts.extend(card.anatomy_tags)
        if card.default_prompt_snippet:
            caption_parts.append(card.default_prompt_snippet)
        caption_parts.extend(subset_tags)

        # Deduplicate while preserving order
        seen = set()
        deduped_parts = []
        for part in caption_parts:
            if part and part not in seen:
                deduped_parts.append(part)
                seen.add(part)

        caption_text = ", ".join(deduped_parts)
        caption_path = subset_dir / f"{image_path.stem}.txt"
        caption_path.write_text(caption_text, encoding="utf-8")
        captions.append(str(caption_path))

    return captions
