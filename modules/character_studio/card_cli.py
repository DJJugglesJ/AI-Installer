"""CLI utilities to manage Character Cards and reference images."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path
from typing import Iterable, List

from .models import CARD_STORAGE_ROOT, CharacterCard


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

    return parser


def main(argv: Iterable[str] | None = None) -> None:
    parser = build_parser()
    args = parser.parse_args(list(argv) if argv is not None else None)
    args.func(args)


if __name__ == "__main__":
    main()
