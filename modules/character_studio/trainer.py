"""Training wrapper stubs for Character Studio."""

from typing import Dict, Optional

# TODO: share CharacterCard registry to populate trainer configs consistently.


def build_training_config(character_id: str) -> Dict:
    """Return a configuration payload for an external LoRA trainer."""
    # TODO: load character metadata and dataset paths.
    return {}


def export_training_pack(character_id: str) -> str:
    """Bundle images, captions, and config into an exportable pack."""
    # TODO: assemble archive path and return location.
    return ""


def run_lora_training(character_id: str) -> Optional[str]:
    """Optional wrapper to invoke the trainer and return the resulting LoRA file path."""
    # TODO: call external trainer (e.g., kohya-ss) and capture logs.
    return None
