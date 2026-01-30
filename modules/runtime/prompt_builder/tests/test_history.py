import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from modules.runtime.prompt_builder.history import PromptHistoryStore


def test_history_store_adds_and_favorites(tmp_path: Path):
    history_path = tmp_path / "history.json"
    store = PromptHistoryStore(history_path=history_path, limit=5)

    entry = store.add_entry(
        {"world": "demo"},
        {"positive_prompt_text": "world: demo", "negative_prompt_text": "", "lora_calls": []},
    )

    entries = store.list_entries()
    assert entries[0].id == entry.id

    updated = store.set_favorite(entry.id, True)
    assert updated.favorite is True
    assert store.list_favorites()[0].id == entry.id
