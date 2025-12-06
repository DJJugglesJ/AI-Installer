"""Dataset management stubs for Character Studio."""

from typing import Iterable, List

# TODO: load Character Cards via shared registry to drive dataset generation defaults.


def create_dataset_structure(character_id: str) -> None:
    """Create base and NSFW dataset directories for a character."""
    # TODO: implement filesystem scaffolding and configuration persistence.


def add_images_to_dataset(character_id: str, images: Iterable[str], subset_name: str) -> List[str]:
    """Add selected images to a dataset subset and return stored paths."""
    # TODO: copy or link images into the dataset folder structure.
    return []


def generate_captions_for_dataset(character_id: str, subset_name: str) -> List[str]:
    """Generate training captions based on Character Card defaults and subset context."""
    # TODO: compose captions using trigger_token plus anatomy/state/pose tags.
    return []
