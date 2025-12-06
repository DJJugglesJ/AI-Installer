"""Tagging utilities for Character Studio."""

from typing import List

# TODO: integrate with external tagger and prompt-derived tags when available.


def auto_tag_images(character_id: str, subset_name: str) -> List[str]:
    """Auto-tag images for a character subset using prompts or external models."""
    # TODO: call tagger service and merge with default anatomy tags.
    return []


def edit_tags_for_image(image_path: str) -> str:
    """Stub for manual tag editing UI hook."""
    # TODO: connect to UI workflow for editing tags and saving captions.
    return ""
