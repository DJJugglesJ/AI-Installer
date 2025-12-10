import json

import pytest

from modules.runtime.character_studio import dataset, models, tagging
from modules.runtime.character_studio.dataset import DatasetOperationError
from modules.runtime.character_studio.models import CharacterCard, SchemaValidationError
from modules.runtime.character_studio.tagging import TaggingError


@pytest.fixture()
def sandbox(tmp_path, monkeypatch):
    card_root = tmp_path / "cards"
    dataset_root = tmp_path / "datasets"
    monkeypatch.setattr(models, "CARD_STORAGE_ROOT", card_root)
    monkeypatch.setattr(dataset, "CARD_STORAGE_ROOT", card_root)
    monkeypatch.setattr(dataset, "DATASET_ROOT", dataset_root)
    dataset_root.mkdir(parents=True, exist_ok=True)
    return card_root, dataset_root


def test_create_dataset_structure_writes_metadata(sandbox):
    card_root, dataset_root = sandbox
    card = CharacterCard(
        id="alice",
        name="Alice",
        nsfw_allowed=True,
        anatomy_tags=["elf"],
        wardrobe=["cloak"],
    )
    card.save()

    dataset.create_dataset_structure(card.id)

    dataset_dir = dataset_root / "characters" / card.id
    assert (dataset_dir / "base").exists()
    assert (dataset_dir / "nsfw").exists()
    metadata = json.loads((dataset_dir / "dataset.json").read_text())
    assert metadata["wardrobe"] == ["cloak"]
    assert metadata["anatomy_tags"] == ["elf"]


def test_generate_captions_blocks_nsfw_without_permission(sandbox, tmp_path):
    card_root, dataset_root = sandbox
    card = CharacterCard(
        id="bob",
        name="Bob",
        nsfw_allowed=False,
        anatomy_tags=["hero"],
    )
    card.save()

    subset_dir = dataset_root / "characters" / card.id / "nsfw"
    subset_dir.mkdir(parents=True, exist_ok=True)
    image_path = subset_dir / "img.png"
    image_path.write_bytes(b"")

    with pytest.raises(DatasetOperationError):
        dataset.generate_captions_for_dataset(card.id, "nsfw")


def test_auto_tag_images_reports_missing_tagger(sandbox):
    card_root, dataset_root = sandbox
    card = CharacterCard(
        id="cora",
        name="Cora",
        nsfw_allowed=False,
        anatomy_tags=["mage"],
    )
    card.save()

    subset_dir = dataset_root / "characters" / card.id / "base"
    subset_dir.mkdir(parents=True, exist_ok=True)
    image_path = subset_dir / "sample.png"
    image_path.write_bytes(b"")

    with pytest.raises(TaggingError) as excinfo:
        tagging.auto_tag_images(card.id, "base", tagger_cmd="definitely_missing_cmd {image}")

    assert excinfo.value.context["command"][0] == "definitely_missing_cmd"


def test_schema_validation_rejects_blank_wardrobe_item():
    card = CharacterCard(
        id="dana",
        name="Dana",
        nsfw_allowed=True,
        anatomy_tags=["warrior"],
        wardrobe=[""],
    )

    with pytest.raises(SchemaValidationError):
        card.validate()
