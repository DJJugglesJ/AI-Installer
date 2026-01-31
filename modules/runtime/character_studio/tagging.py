"""Tagging utilities for Character Studio."""

from __future__ import annotations

import logging
import os
import shlex
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, Iterable, List, Optional

from . import dataset
from .models import CharacterCard, CharacterStudioError, SchemaValidationError

logger = logging.getLogger(__name__)


class TaggingError(CharacterStudioError):
    """Raised when tagging operations fail."""


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


def parse_tag_text(tag_text: str) -> List[str]:
    """Parse tag text into a normalized list."""

    return _parse_tag_output(tag_text)


def _normalize_tag_list(tags: Iterable[str]) -> List[str]:
    normalized: List[str] = []
    for tag in tags:
        if not isinstance(tag, str):
            raise TaggingError("Tags must be strings", context={"tag": tag})
        stripped = tag.strip()
        if stripped and stripped not in normalized:
            normalized.append(stripped)
    return normalized


def _coerce_character_card(character_card: CharacterCard | Dict[str, object]) -> CharacterCard:
    if isinstance(character_card, CharacterCard):
        card = character_card
    elif isinstance(character_card, dict):
        card = CharacterCard.from_dict(character_card)
    else:
        raise TaggingError(
            "character_card must be a CharacterCard or dict payload",
            context={"type": type(character_card).__name__},
        )

    try:
        card.normalize_triggers()
        card.validate()
    except SchemaValidationError as exc:
        raise TaggingError("Invalid Character Card input", context={"errors": exc.context}) from exc
    return card


def _extract_existing_tags(image_context: Dict[str, object]) -> List[str]:
    existing_tags: List[str] = []
    if "existing_tags" in image_context and image_context["existing_tags"] is not None:
        if not isinstance(image_context["existing_tags"], list):
            raise TaggingError("existing_tags must be a list of strings", context={"existing_tags": image_context})
        existing_tags.extend(_normalize_tag_list(image_context["existing_tags"]))
    caption = image_context.get("caption")
    if isinstance(caption, str) and caption.strip():
        existing_tags.extend(_parse_tag_output(caption))
    return _normalize_tag_list(existing_tags)


def batch_tag_images(
    character_card: CharacterCard | Dict[str, object], image_contexts: Iterable[Dict[str, object]]
) -> Dict[str, object]:
    """Generate tags for multiple images using a Character Card and context."""

    card = _coerce_character_card(character_card)
    contexts = list(image_contexts)
    if not contexts:
        return {"tags_by_image": {}, "metadata": {"character_id": card.id, "count": 0}}

    base_tags: List[str] = []
    if card.trigger_token:
        base_tags.append(card.trigger_token)
    base_tags.extend(card.trigger_tokens)
    base_tags.extend(card.anatomy_tags)
    base_tags.extend(card.wardrobe)
    if card.default_prompt_snippet:
        base_tags.append(card.default_prompt_snippet)
    base_tags = _normalize_tag_list(base_tags)

    tags_by_image: Dict[str, List[str]] = {}
    for context in contexts:
        if not isinstance(context, dict):
            raise TaggingError("image_contexts must contain dict entries", context={"context": context})
        image_path = context.get("image_path")
        if not isinstance(image_path, str) or not image_path.strip():
            raise TaggingError("image_path is required in image_context", context={"context": context})

        extra_tags = context.get("extra_tags", [])
        if extra_tags and not isinstance(extra_tags, list):
            raise TaggingError("extra_tags must be a list of strings", context={"extra_tags": extra_tags})

        existing_tags = _extract_existing_tags(context)
        merged = _normalize_tag_list(base_tags + existing_tags + _normalize_tag_list(extra_tags or []))
        tags_by_image[image_path] = merged

    return {
        "tags_by_image": tags_by_image,
        "metadata": {"character_id": card.id, "count": len(tags_by_image)},
    }


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
        logger.warning(
            "No images available for auto-tagging",
            extra={"character_id": character_id, "subset": subset_name},
        )
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
                raise TaggingError(
                    "External tagger command not found",
                    context={"character_id": character_id, "subset": subset_name, "command": cmd},
                ) from exc
            except subprocess.CalledProcessError as exc:
                raise TaggingError(
                    "External tagger failed",
                    context={
                        "character_id": character_id,
                        "subset": subset_name,
                        "command": cmd,
                        "stderr": exc.stderr,
                    },
                ) from exc

        results.append(_write_caption(image, tags))

    logger.info(
        "Tagged images",
        extra={"character_id": character_id, "subset": subset_name, "count": len(results)},
    )
    return results


def edit_tags_for_image(image_path: str, new_tags: Optional[List[str]] = None) -> str:
    """Manual tag editing helper used by UI or CLI workflows."""

    path = Path(image_path)
    if path.suffix.lower() not in dataset.IMAGE_EXTENSIONS:
        raise TaggingError(
            "edit_tags_for_image expects an image path",
            context={"image_path": image_path, "suffix": path.suffix},
        )

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
        raise TaggingError(
            "Use either append_tags or replace_with, not both",
            context={"append_tags": append_tags, "replace_with": replace_with},
        )

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

    logger.info("Bulk tag edit complete", extra={"updated": len(updated)})
    return updated
