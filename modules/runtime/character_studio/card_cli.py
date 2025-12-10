"""CLI utilities to manage Character Cards and reference images."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path
from typing import Iterable, List

from . import dataset, tagging, trainer
from .models import CARD_STORAGE_ROOT, CharacterCard, CharacterStudioError


CARD_FILENAME = "card.json"


def _get_card_dir(card_id: str) -> Path:
    return CARD_STORAGE_ROOT / card_id


def _get_reference_dir(card_id: str) -> Path:
    return _get_card_dir(card_id) / "references"


def _get_card_path(card_id: str) -> Path:
    return _get_card_dir(card_id) / CARD_FILENAME


def _parse_tags(tag_text: str | None) -> List[str]:
    if not tag_text:
        return []
    return [tag.strip() for tag in tag_text.split(",") if tag.strip()]


def _parse_wardrobe(wardrobe_text: str | None) -> List[str]:
    if not wardrobe_text:
        return []
    return [item.strip() for item in wardrobe_text.split(",") if item.strip()]


def _load_existing_card(card_id: str) -> CharacterCard:
    card_path = _get_card_path(card_id)
    if not card_path.exists():
        raise FileNotFoundError(f"Card {card_id} does not exist at {card_path}")
    return CharacterCard.load(card_id, path=card_path)


def create_card(args: argparse.Namespace) -> None:
    tags = _parse_tags(args.anatomy_tags)
    card = CharacterCard(
        id=args.id,
        name=args.name,
        age=args.age,
        nsfw_allowed=args.nsfw,
        description=args.description,
        default_prompt_snippet=args.default_prompt_snippet,
        trigger_token=args.trigger_token,
        anatomy_tags=tags,
        wardrobe=_parse_wardrobe(args.wardrobe),
        lora_file=args.lora_file,
        lora_default_strength=args.lora_default_strength,
    )
    destination = card.save(path=_get_card_path(args.id))
    print(f"Saved card to {destination}")


def edit_card(args: argparse.Namespace) -> None:
    card = _load_existing_card(args.id)
    if args.name:
        card.name = args.name
    if args.age:
        card.age = args.age
    if args.nsfw is not None:
        card.nsfw_allowed = args.nsfw
    if args.description:
        card.description = args.description
    if args.default_prompt_snippet:
        card.default_prompt_snippet = args.default_prompt_snippet
    if args.trigger_token:
        card.trigger_token = args.trigger_token
    if args.anatomy_tags:
        card.anatomy_tags = _parse_tags(args.anatomy_tags)
    if args.wardrobe:
        card.wardrobe = _parse_wardrobe(args.wardrobe)
    if args.lora_file:
        card.lora_file = args.lora_file
    if args.lora_default_strength is not None:
        card.lora_default_strength = args.lora_default_strength
    destination = card.save(path=_get_card_path(args.id))
    print(f"Updated card at {destination}")


def attach_reference_images(args: argparse.Namespace) -> None:
    card = _load_existing_card(args.id)
    reference_dir = _get_reference_dir(args.id)
    reference_dir.mkdir(parents=True, exist_ok=True)

    new_paths: List[str] = []
    for image_path_str in args.images:
        image_path = Path(image_path_str).expanduser().resolve()
        if not image_path.exists():
            raise FileNotFoundError(f"Reference image not found: {image_path}")
        destination = reference_dir / image_path.name
        shutil.copy(image_path, destination)
        stored_path = str(destination.relative_to(CARD_STORAGE_ROOT))
        if stored_path not in card.reference_images:
            card.reference_images.append(stored_path)
        new_paths.append(stored_path)

    card.save(path=_get_card_path(args.id))
    print(f"Attached references: {', '.join(new_paths)}")


def show_card(args: argparse.Namespace) -> None:
    card = _load_existing_card(args.id)
    print(json.dumps(card.to_dict(), indent=2))


def list_cards(_: argparse.Namespace) -> None:
    if not CARD_STORAGE_ROOT.exists():
        print("No cards found.")
        return
    for card_dir in sorted(CARD_STORAGE_ROOT.iterdir()):
        if not card_dir.is_dir():
            continue
        card_path = card_dir / CARD_FILENAME
        if card_path.exists():
            card = CharacterCard.load(card_dir.name, path=card_path)
            print(f"{card.id}: {card.name} (NSFW: {card.nsfw_allowed})")


def create_dataset(args: argparse.Namespace) -> None:
    dataset.create_dataset_structure(args.id)
    print(f"Initialized dataset at {dataset.get_character_dataset_dir(args.id)}")


def add_dataset_images(args: argparse.Namespace) -> None:
    stored = dataset.add_images_to_dataset(args.id, args.images, args.subset)
    print("Added images:\n" + "\n".join(stored))


def caption_dataset(args: argparse.Namespace) -> None:
    captions = dataset.generate_captions_for_dataset(args.id, args.subset)
    if not captions:
        print("No images found to caption.")
        return
    print("Generated captions:\n" + "\n".join(captions))


def auto_tag_dataset(args: argparse.Namespace) -> None:
    extra_tags = _parse_tags(args.extra_tags)
    captions = tagging.auto_tag_images(args.id, args.subset, tagger_cmd=args.tagger, extra_tags=extra_tags)
    if not captions:
        print("No images tagged.")
        return
    print("Tagged images:\n" + "\n".join(captions))


def bulk_edit_dataset_tags(args: argparse.Namespace) -> None:
    targets: List[str] = []
    if args.images:
        targets = list(args.images)
    else:
        targets = [str(p) for p in dataset.list_subset_images(args.id, args.subset)]

    if not targets:
        print("No images found for tag editing.")
        return

    updated = tagging.bulk_edit_tags(targets, append_tags=_parse_tags(args.append), replace_with=_parse_tags(args.replace))
    print("Updated tags for:\n" + "\n".join(updated))


def export_training(args: argparse.Namespace) -> None:
    archive = trainer.export_training_pack(args.id)
    print(f"Exported training pack to {archive}")


def run_training(args: argparse.Namespace) -> None:
    output = trainer.run_lora_training(args.id)
    if output:
        print(f"Trainer produced LoRA: {output}")
    else:
        print("Trainer not invoked or no output was produced.")



def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Manage Character Cards for Character Studio")
    subparsers = parser.add_subparsers(dest="command", required=True)

    create = subparsers.add_parser("create", help="Create a new Character Card")
    create.add_argument("id", help="Unique character id")
    create.add_argument("name", help="Display name")
    create.add_argument("--age", help="Age or age range")
    create.add_argument("--nsfw", action="store_true", help="Allow NSFW content")
    create.add_argument("--description", help="Description for the character")
    create.add_argument("--default-prompt-snippet", dest="default_prompt_snippet", help="Default prompt snippet")
    create.add_argument("--trigger-token", dest="trigger_token", help="Trigger token")
    create.add_argument("--anatomy-tags", dest="anatomy_tags", help="Comma separated anatomy tags")
    create.add_argument("--wardrobe", dest="wardrobe", help="Comma separated wardrobe descriptors")
    create.add_argument("--lora-file", dest="lora_file", help="LoRA file path")
    create.add_argument("--lora-default-strength", dest="lora_default_strength", type=float)
    create.set_defaults(func=create_card)

    edit = subparsers.add_parser("edit", help="Edit an existing Character Card")
    edit.add_argument("id", help="Unique character id")
    edit.add_argument("--name", help="Display name")
    edit.add_argument("--age", help="Age or age range")
    edit.add_argument("--nsfw", dest="nsfw", action=argparse.BooleanOptionalAction, help="Allow NSFW content")
    edit.add_argument("--description", help="Description for the character")
    edit.add_argument("--default-prompt-snippet", dest="default_prompt_snippet", help="Default prompt snippet")
    edit.add_argument("--trigger-token", dest="trigger_token", help="Trigger token")
    edit.add_argument("--anatomy-tags", dest="anatomy_tags", help="Comma separated anatomy tags")
    edit.add_argument("--wardrobe", dest="wardrobe", help="Comma separated wardrobe descriptors")
    edit.add_argument("--lora-file", dest="lora_file", help="LoRA file path")
    edit.add_argument("--lora-default-strength", dest="lora_default_strength", type=float)
    edit.set_defaults(func=edit_card)

    attach = subparsers.add_parser("attach-images", help="Attach reference images to a Character Card")
    attach.add_argument("id", help="Unique character id")
    attach.add_argument("images", nargs="+", help="Paths to reference images")
    attach.set_defaults(func=attach_reference_images)

    show = subparsers.add_parser("show", help="Show a Character Card JSON")
    show.add_argument("id", help="Unique character id")
    show.set_defaults(func=show_card)

    list_cmd = subparsers.add_parser("list", help="List saved Character Cards")
    list_cmd.set_defaults(func=list_cards)

    dataset_create = subparsers.add_parser("init-dataset", help="Create dataset folders for a Character Card")
    dataset_create.add_argument("id", help="Unique character id")
    dataset_create.set_defaults(func=create_dataset)

    dataset_add = subparsers.add_parser("add-dataset-images", help="Copy images into a dataset subset")
    dataset_add.add_argument("id", help="Unique character id")
    dataset_add.add_argument("subset", help="Subset name (e.g., base, nsfw/variant_a)")
    dataset_add.add_argument("images", nargs="+", help="Image paths to copy")
    dataset_add.set_defaults(func=add_dataset_images)

    dataset_caption = subparsers.add_parser("generate-captions", help="Create caption files for a subset")
    dataset_caption.add_argument("id", help="Unique character id")
    dataset_caption.add_argument("subset", help="Subset name (e.g., base or nsfw)")
    dataset_caption.set_defaults(func=caption_dataset)

    dataset_tag = subparsers.add_parser("auto-tag", help="Auto-tag a dataset subset")
    dataset_tag.add_argument("id", help="Unique character id")
    dataset_tag.add_argument("subset", help="Subset name")
    dataset_tag.add_argument("--tagger", help="External tagger command overriding CHAR_STUDIO_TAGGER_CMD")
    dataset_tag.add_argument("--extra-tags", help="Comma separated tags to append to each caption")
    dataset_tag.set_defaults(func=auto_tag_dataset)

    dataset_tag_edit = subparsers.add_parser("edit-tags", help="Manually edit or bulk-append tags")
    dataset_tag_edit.add_argument("id", help="Unique character id")
    dataset_tag_edit.add_argument("subset", help="Subset name")
    dataset_tag_edit.add_argument("--images", nargs="*", help="Specific image paths to edit; defaults to all in subset")
    dataset_tag_edit.add_argument("--append", help="Comma separated tags to append")
    dataset_tag_edit.add_argument("--replace", help="Comma separated tags to replace existing captions")
    dataset_tag_edit.set_defaults(func=bulk_edit_dataset_tags)

    export_pack = subparsers.add_parser("export-training", help="Create a portable training pack")
    export_pack.add_argument("id", help="Unique character id")
    export_pack.set_defaults(func=export_training)

    train_cmd = subparsers.add_parser("train", help="Invoke configured trainer for a character")
    train_cmd.add_argument("id", help="Unique character id")
    train_cmd.set_defaults(func=run_training)

    return parser


def main(argv: Iterable[str] | None = None) -> None:
    parser = build_parser()
    args = parser.parse_args(list(argv) if argv is not None else None)
    try:
        args.func(args)
    except CharacterStudioError as exc:
        payload = {"error": str(exc), "context": getattr(exc, "context", {})}
        print(json.dumps(payload, indent=2))
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
