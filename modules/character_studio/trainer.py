"""Training wrappers for Character Studio."""

from __future__ import annotations

import json
import os
import shlex
import shutil
import subprocess
from pathlib import Path
from typing import Dict, List, Optional

from . import dataset
from .models import CARD_STORAGE_ROOT, CharacterCard


def _load_card(character_id: str) -> CharacterCard:
    card_path = CARD_STORAGE_ROOT / character_id / "card.json"
    if not card_path.exists():
        raise FileNotFoundError(f"Character Card not found for id {character_id} at {card_path}")
    return CharacterCard.load(character_id, path=card_path)


def _collect_subsets(character_id: str) -> List[Dict[str, str]]:
    base_dir = dataset.get_subset_dir(character_id, "base")
    subsets: List[Dict[str, str]] = []
    if base_dir.exists():
        subsets.append({"name": "base", "path": str(base_dir)})

    nsfw_dir = dataset.get_subset_dir(character_id, "nsfw")
    if nsfw_dir.exists():
        subsets.append({"name": "nsfw", "path": str(nsfw_dir)})

    for subdir in dataset.get_character_dataset_dir(character_id).glob("*"):
        if subdir in {base_dir, nsfw_dir} or not subdir.is_dir():
            continue
        subsets.append({"name": subdir.relative_to(dataset.get_character_dataset_dir(character_id)).as_posix(), "path": str(subdir)})
    return subsets


def build_training_config(character_id: str) -> Dict:
    """Return a configuration payload for an external LoRA trainer."""

    card = _load_card(character_id)
    dataset_root = dataset.get_character_dataset_dir(character_id)
    output_dir = dataset_root / "outputs"
    output_dir.mkdir(parents=True, exist_ok=True)
    lora_output = output_dir / f"{character_id}_lora.safetensors"

    config = {
        "character_id": card.id,
        "name": card.name,
        "trigger_token": card.trigger_token,
        "anatomy_tags": card.anatomy_tags,
        "dataset_root": str(dataset_root),
        "nsfw_allowed": card.nsfw_allowed,
        "subsets": _collect_subsets(character_id),
        "output_path": str(lora_output),
        "lora_default_strength": card.lora_default_strength or 0.7,
    }

    return config


def export_training_pack(character_id: str) -> str:
    """Bundle images, captions, and config into an exportable pack."""

    dataset_dir = dataset.get_character_dataset_dir(character_id)
    if not dataset_dir.exists():
        raise FileNotFoundError(f"Dataset not initialized for {character_id}. Run create_dataset_structure first.")

    config = build_training_config(character_id)
    pack_dir = dataset_dir / "training_pack"
    pack_dir.mkdir(parents=True, exist_ok=True)

    config_path = pack_dir / "training_config.json"
    config_path.write_text(json.dumps(config, indent=2), encoding="utf-8")

    archive_base = pack_dir / "pack"
    archive_path = shutil.make_archive(str(archive_base), "zip", root_dir=dataset_dir)
    return archive_path


def run_lora_training(character_id: str) -> Optional[str]:
    """Optional wrapper to invoke the trainer and return the resulting LoRA file path."""

    trainer_cmd = os.getenv("CHAR_STUDIO_TRAINER_CMD")
    config = build_training_config(character_id)
    dataset_dir = dataset.get_character_dataset_dir(character_id)
    config_path = dataset_dir / "training_config.json"
    config_path.write_text(json.dumps(config, indent=2), encoding="utf-8")

    if not trainer_cmd:
        print("CHAR_STUDIO_TRAINER_CMD not configured; exported training_config.json for manual runs.")
        return None

    cmd = [part.format(config=str(config_path), dataset=str(dataset_dir), output=config["output_path"]) for part in shlex.split(trainer_cmd)]
    try:
        subprocess.run(cmd, check=True)
    except FileNotFoundError as exc:
        raise RuntimeError(f"Trainer command not found: {cmd[0]}") from exc
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(f"Trainer failed for {character_id}: {exc}") from exc

    output_path = Path(config["output_path"])
    if output_path.exists():
        card = _load_card(character_id)
        card.lora_file = str(output_path)
        if card.lora_default_strength is None:
            card.lora_default_strength = config.get("lora_default_strength", 0.7)
        card.save(path=CARD_STORAGE_ROOT / character_id / "card.json")
        return str(output_path)

    return None
