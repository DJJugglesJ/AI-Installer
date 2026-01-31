import json
import pytest
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from modules.runtime.character_studio import card_cli, models
from modules.runtime.character_studio.models import CHARACTER_CARD_SCHEMA, CharacterCard, apply_feedback_to_character


@pytest.fixture(autouse=True)
def reset_storage_root(tmp_path, monkeypatch):
    """Isolate Character Card storage per-test."""

    monkeypatch.setattr(models, "CARD_STORAGE_ROOT", tmp_path)
    monkeypatch.setattr(card_cli, "CARD_STORAGE_ROOT", tmp_path)
    return tmp_path


def test_schema_has_required_fields():
    assert CHARACTER_CARD_SCHEMA["title"] == "CharacterCard"
    for required in ["id", "name", "nsfw_allowed", "anatomy_tags"]:
        assert required in CHARACTER_CARD_SCHEMA["required"]
        assert required in CHARACTER_CARD_SCHEMA["properties"]


def test_serialization_round_trip(tmp_path):
    card = CharacterCard(
        id="test-hero",
        name="Test Hero",
        age="21",
        nsfw_allowed=False,
        description="A brave protagonist",
        default_prompt_snippet="cinematic lighting",
        trigger_token="testhero",
        anatomy_tags=["athletic build", "cape"],
        lora_file="hero.safetensors",
        lora_default_strength=0.8,
        reference_images=["hero/ref1.png"],
        metadata={"creator": "qa"},
    )
    saved_path = card.save(path=tmp_path / "card.json")

    loaded = CharacterCard.load(card_id="test-hero", path=saved_path)
    assert card.to_dict() == loaded.to_dict()


def test_trigger_token_parity_round_trip():
    payload = {
        "id": "hero",
        "name": "Hero",
        "nsfw_allowed": False,
        "anatomy_tags": ["cape"],
        "trigger_token": "summon-hero",
    }
    card = CharacterCard.from_dict(payload)
    serialized = card.to_dict()

    assert serialized["trigger_tokens"] == ["summon-hero"]
    reloaded = CharacterCard.from_dict(serialized)
    assert reloaded.trigger_tokens == ["summon-hero"]

    payload_with_tokens = {
        "id": "mage",
        "name": "Mage",
        "nsfw_allowed": False,
        "anatomy_tags": ["robe"],
        "trigger_tokens": ["summon-mage", "arcane"],
    }
    card_with_tokens = CharacterCard.from_dict(payload_with_tokens)
    serialized_with_tokens = card_with_tokens.to_dict()

    assert serialized_with_tokens["trigger_tokens"] == ["summon-mage", "arcane"]
    assert card_with_tokens.trigger_token == "summon-mage"


def test_feedback_updates_fields():
    card = CharacterCard(id="hero", name="Hero", anatomy_tags=["cape"], nsfw_allowed=False)
    feedback = "description: moodier tone; anatomy_tags: silver eyes, windswept hair; nsfw_allowed: true"
    updated = apply_feedback_to_character(card, feedback)

    assert updated.description == "moodier tone"
    assert "silver eyes" in updated.anatomy_tags
    assert updated.nsfw_allowed is True


def test_cli_create_and_attach_reference_images(tmp_path):
    image_path = tmp_path / "ref.png"
    image_path.write_bytes(b"fake image")

    card_cli.main([
        "create",
        "card-1",
        "Card One",
        "--description",
        "Sample",
        "--anatomy-tags",
        "tag-a,tag-b",
        "--nsfw",
    ])

    card_cli.main([
        "attach-images",
        "card-1",
        str(image_path),
    ])

    saved_card = CharacterCard.load("card-1", path=tmp_path / "card-1" / "card.json")
    assert saved_card.reference_images
    stored_ref = saved_card.reference_images[0]
    stored_path = models.CARD_STORAGE_ROOT / stored_ref
    assert stored_path.exists()
    assert saved_card.anatomy_tags == ["tag-a", "tag-b"]
    assert saved_card.nsfw_allowed is True


def test_cli_emits_standard_success_shape(capsys):
    card_cli.main([
        "create",
        "card-json",
        "Card Json",
        "--anatomy-tags",
        "tag-a",
    ])
    output = capsys.readouterr().out
    payload = json.loads(output)

    assert payload["error"] is None
    assert payload["metadata"] == {}
    assert payload["data"]["path"].endswith("card-json/card.json")


def test_cli_emits_standard_error_shape(capsys):
    with pytest.raises(SystemExit):
        card_cli.main(["show", "missing-card"])
    output = capsys.readouterr().out
    payload = json.loads(output)

    assert payload["data"] is None
    assert payload["metadata"] == {}
    assert "does not exist" in payload["error"]["message"]
