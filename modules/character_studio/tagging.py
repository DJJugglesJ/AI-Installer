"""Tagging utilities for Character Studio."""

from __future__ import annotations

import os
import shlex
import subprocess
import tempfile
from pathlib import Path
from typing import Iterable, List, Optional

from . import dataset
from .models import CharacterCard


def _load_card(character_id: str) -> CharacterCard:
    return CharacterCard.load(character_id)


def _parse_tag_output(output: str) -> List[str]:
    """Parse comma or newline separated tag text from an external tagger."""

    raw_tags = output.replace("\n", ",").split(",")
    parsed = []
    for tag in raw_tags:
        stripped = tag.strip()
        if stripped and stripped not in parsed:
            parsed.append(stripped)
    return parsed


def _write_caption(image_path: Path, tags: List[str]) -> str:
    caption_text = ", ".join(tags)
    caption_path = image_path.with_suffix(".txt")
    caption_path.write_text(caption_text, encoding="utf-8")
    return str(caption_path)


def auto_tag_images(
    character_id: str, subset_name: str, *, tagger_cmd: Optional[str] = None, extra_tags: Optional[List[str]] = None
) -> List[str]:
    """Auto-tag images for a character subset using prompts or external models.

    A custom external command can be supplied via ``tagger_cmd`` or the environment
    variable ``CHAR_STUDIO_TAGGER_CMD``. The command is expanded with
    ``str.format`` and receives ``{image}`` and ``{subset}`` placeholders.
    """

    card = _load_card(character_id)
    images = dataset.list_subset_images(character_id, subset_name)
    if not images:
        return []

    base_tags: List[str] = []
    if card.trigger_token:
        base_tags.append(card.trigger_token)
    base_tags.extend(card.anatomy_tags)
    if extra_tags:
        base_tags.extend(extra_tags)

    results: List[str] = []
    external_cmd = tagger_cmd or os.getenv("CHAR_STUDIO_TAGGER_CMD")

    for image in images:
        tags = list(dict.fromkeys(base_tags))
        if external_cmd:
            cmd = [part.format(image=str(image), subset=subset_name) for part in shlex.split(external_cmd)]
            try:
                completed = subprocess.run(cmd, capture_output=True, text=True, check=True)
                generated_tags = _parse_tag_output(completed.stdout)
                for tag in generated_tags:
                    if tag not in tags:
                        tags.append(tag)
            except FileNotFoundError as exc:
                raise RuntimeError(f"External tagger not found: {cmd[0]}") from exc
            except subprocess.CalledProcessError as exc:
                raise RuntimeError(f"External tagger failed for {image}: {exc.stderr}") from exc

        results.append(_write_caption(image, tags))

    return results


def edit_tags_for_image(image_path: str, new_tags: Optional[List[str]] = None) -> str:
    """Manual tag editing helper used by UI or CLI workflows."""

    path = Path(image_path)
    if path.suffix.lower() not in dataset.IMAGE_EXTENSIONS:
        raise ValueError("edit_tags_for_image expects an image path")

    caption_path = path.with_suffix(".txt")
    existing = caption_path.read_text(encoding="utf-8") if caption_path.exists() else ""

    if new_tags is None:
        editor = os.getenv("EDITOR")
        if editor:
            with tempfile.NamedTemporaryFile(mode="w+", delete=False) as temp_file:
                temp_file.write(existing)
                temp_file.flush()
                subprocess.run(shlex.split(editor) + [temp_file.name], check=False)
                temp_file.seek(0)
                updated = temp_file.read().strip()
            Path(temp_file.name).unlink(missing_ok=True)
            tags = _parse_tag_output(updated)
        else:
            updated = input(f"Enter tags for {image_path} (comma separated) [{existing}]: ").strip() or existing
            tags = _parse_tag_output(updated)
    else:
        tags = new_tags

    return _write_caption(path, list(dict.fromkeys(tags)))


def bulk_edit_tags(
    image_paths: Iterable[str], *, append_tags: Optional[List[str]] = None, replace_with: Optional[List[str]] = None
) -> List[str]:
    """Apply bulk tag edits across multiple images."""

    if append_tags and replace_with:
        raise ValueError("Use either append_tags or replace_with, not both")

    updated: List[str] = []
    for image_path_str in image_paths:
        path = Path(image_path_str)
        if replace_with is not None:
            updated.append(edit_tags_for_image(str(path), new_tags=list(dict.fromkeys(replace_with))))
            continue

        caption_path = path.with_suffix(".txt")
        existing_tags: List[str] = []
        if caption_path.exists():
            existing_tags = _parse_tag_output(caption_path.read_text(encoding="utf-8"))

        merged = existing_tags + [tag for tag in (append_tags or []) if tag not in existing_tags]
        updated.append(_write_caption(path, merged))

    return updated
