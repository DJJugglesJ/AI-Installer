import json
from copy import deepcopy
from pathlib import Path

import pytest

from modules.config_service import config_service
from modules.runtime.character_studio import dataset, models, tagging
from modules.runtime.character_studio.dataset import DatasetOperationError
from modules.runtime.character_studio.models import CharacterCard, SchemaValidationError
from modules.runtime.character_studio.tagging import TaggingError
from modules.runtime.web_launcher.server import WebLauncherAPI


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


def test_get_dataset_summary_reports_counts(sandbox):
    card_root, dataset_root = sandbox
    card = CharacterCard(
        id="blake",
        name="Blake",
        nsfw_allowed=False,
        anatomy_tags=["pilot"],
    )
    card.save()

    dataset.create_dataset_structure(card.id)
    subset_dir = dataset_root / "characters" / card.id / "base"
    image_path = subset_dir / "sample.png"
    image_path.write_bytes(b"")
    caption_path = subset_dir / "sample.txt"
    caption_path.write_text("pilot", encoding="utf-8")

    summary = dataset.get_dataset_summary(card.id)

    assert summary["exists"] is True
    assert summary["total_images"] == 1
    assert summary["total_captioned"] == 1
    assert summary["total_missing_captions"] == 0
    assert summary["subsets"][0]["name"] == "base"
    assert summary["subsets"][0]["image_count"] == 1
    assert summary["subsets"][0]["captioned_count"] == 1


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


def test_web_launcher_dataset_review_endpoints(sandbox, tmp_path):
    card_root, dataset_root = sandbox
    card = CharacterCard(
        id="hana",
        name="Hana",
        nsfw_allowed=False,
        anatomy_tags=["ranger"],
    )
    card.save()

    dataset.create_dataset_structure(card.id)
    subset_dir = dataset_root / "characters" / card.id / "base"
    image_path = subset_dir / "sample.png"
    image_path.write_bytes(b"")
    caption_path = subset_dir / "sample.txt"
    caption_path.write_text("tag1, tag2", encoding="utf-8")

    api = WebLauncherAPI(
        project_root=Path(__file__).resolve().parents[4],
        log_dir=tmp_path / "logs",
        history_path=tmp_path / "history.json",
    )

    images = api.list_dataset_images(card.id, "base")
    assert images["count"] == 1
    assert images["items"][0]["caption_exists"] is True

    caption = api.get_dataset_caption(card.id, {"image_path": str(image_path)})
    assert caption["caption"] == "tag1, tag2"
    assert caption["tags"] == ["tag1", "tag2"]

    updated = api.edit_dataset_tags(card.id, {"image_path": str(image_path), "tags": ["alpha", "beta"]})
    assert updated["tags"] == ["alpha", "beta"]
    assert caption_path.read_text(encoding="utf-8") == "alpha, beta"


def test_web_launcher_bulk_tag_edit(sandbox, tmp_path):
    card_root, dataset_root = sandbox
    card = CharacterCard(
        id="ivy",
        name="Ivy",
        nsfw_allowed=False,
        anatomy_tags=["pilot"],
    )
    card.save()

    dataset.create_dataset_structure(card.id)
    subset_dir = dataset_root / "characters" / card.id / "base"
    image_paths = []
    for name in ("first.png", "second.png"):
        image_path = subset_dir / name
        image_path.write_bytes(b"")
        image_path.with_suffix(".txt").write_text("starter", encoding="utf-8")
        image_paths.append(str(image_path))

    api = WebLauncherAPI(
        project_root=Path(__file__).resolve().parents[4],
        log_dir=tmp_path / "logs",
        history_path=tmp_path / "history.json",
    )

    result = api.bulk_edit_dataset_tags(card.id, {"image_paths": image_paths, "append_tags": ["extra"]})
    assert result["count"] == 2
    assert (subset_dir / "first.txt").read_text(encoding="utf-8") == "starter, extra"
    assert (subset_dir / "second.txt").read_text(encoding="utf-8") == "starter, extra"


def test_batch_tag_images_returns_tags_by_image(sandbox):
    card_root, dataset_root = sandbox
    card = CharacterCard(
        id="juno",
        name="Juno",
        nsfw_allowed=False,
        anatomy_tags=["android"],
        wardrobe=["jacket"],
        trigger_token="juno_tok",
        trigger_tokens=["juno_tok", "juno_alt"],
        default_prompt_snippet="soft lighting",
    )
    card.save()

    dataset.create_dataset_structure(card.id)
    subset_dir = dataset_root / "characters" / card.id / "base"
    image_path = subset_dir / "sample.png"
    image_path.write_bytes(b"")
    image_path.with_suffix(".txt").write_text("portrait, smile", encoding="utf-8")

    contexts = dataset.load_image_contexts(card.id, "base")
    result = tagging.batch_tag_images(card.to_dict(), contexts)

    assert result["metadata"]["character_id"] == card.id
    assert result["metadata"]["count"] == 1
    tags = result["tags_by_image"][str(image_path)]
    assert tags == ["juno_tok", "juno_alt", "android", "jacket", "soft lighting", "portrait", "smile"]


def test_batch_tag_images_rejects_invalid_context(sandbox):
    card_root, dataset_root = sandbox
    card = CharacterCard(
        id="kira",
        name="Kira",
        nsfw_allowed=False,
        anatomy_tags=["pilot"],
    )
    card.save()

    with pytest.raises(TaggingError):
        tagging.batch_tag_images(card, [{"caption": "missing image_path"}])


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


def test_schema_validation_rejects_blank_trigger_tokens():
    card = CharacterCard(
        id="erin",
        name="Erin",
        nsfw_allowed=False,
        anatomy_tags=["mage"],
        wardrobe=["robe"],
        trigger_tokens=[""],
    )

    with pytest.raises(SchemaValidationError):
        card.validate()


def _write_config(tmp_path, data):
    path = tmp_path / "config.json"
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    return path


def test_apply_feedback_uses_preset_provider(tmp_path):
    config = deepcopy(config_service.DEFAULT_CONFIG)
    config["llm"]["provider"] = "preset"
    config["llm"]["fallback_provider"] = "deterministic"
    config["llm"]["providers"]["preset"]["character_overrides"] = {
        "refresh character": {"description": "new bio", "anatomy_tags": ["sharp"]}
    }
    config_path = _write_config(tmp_path, config)

    card = CharacterCard(
        id="faye",
        name="Faye",
        nsfw_allowed=False,
        anatomy_tags=["pilot"],
    )

    updated = models.apply_feedback_to_character(card, "refresh character", config_path=config_path)

    assert updated.description == "new bio"
    assert "sharp" in updated.anatomy_tags


def test_apply_feedback_falls_back_to_deterministic(tmp_path):
    config = deepcopy(config_service.DEFAULT_CONFIG)
    config["llm"]["provider"] = "missing"
    config["llm"]["fallback_provider"] = "deterministic"
    config_path = _write_config(tmp_path, config)

    card = CharacterCard(
        id="gwen",
        name="Gwen",
        nsfw_allowed=False,
        anatomy_tags=["mage"],
    )

    updated = models.apply_feedback_to_character(
        card,
        "description: veteran mage; anatomy_tags: stoic",
        config_path=config_path,
    )

    assert updated.description == "veteran mage"
    assert "stoic" in updated.anatomy_tags
