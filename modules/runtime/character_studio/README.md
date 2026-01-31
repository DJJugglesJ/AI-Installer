# Character Studio CLI workflows

The Character Studio CLI builds on Character Cards to prepare datasets, tag images, and export training packs.
Commands live in `modules/runtime/character_studio/card_cli.py`.
The Web Launcher UI also exposes Character Studio workflows via `modules/runtime/web_launcher/static/character_studio.html`.

## Character Cards
- Create a card:
  ```bash
  python -m modules.runtime.character_studio.card_cli create alice "Alice" --trigger-token "alice_tok" --anatomy-tags "freckles, ponytail"
  ```
- Edit metadata:
  ```bash
  python -m modules.runtime.character_studio.card_cli edit alice --nsfw --lora-default-strength 0.8
  ```
- Attach reference images (copies files into the card's `character_cards/<id>/references` folder and stores relative paths on the card):
  ```bash
  python -m modules.runtime.character_studio.card_cli attach-images alice ./refs/alice_01.png ./refs/alice_02.png
  ```
- Show or list cards:
  ```bash
  python -m modules.runtime.character_studio.card_cli show alice
  python -m modules.runtime.character_studio.card_cli list
  ```

## Dataset preparation
- Initialize the dataset folders (creates `base/` and optionally `nsfw/`):
  ```bash
  python -m modules.runtime.character_studio.card_cli init-dataset alice
  ```
- Add images to a subset and generate captions that include the trigger token and anatomy tags:
  ```bash
  python -m modules.runtime.character_studio.card_cli add-dataset-images alice base ./captures/*.png
  python -m modules.runtime.character_studio.card_cli generate-captions alice base
  ```

## Tagging
- Auto-tag with an external tagger (pass `--tagger` or set `CHAR_STUDIO_TAGGER_CMD`).
  The command receives `{image}` and `{subset}` placeholders.
  ```bash
  python -m modules.runtime.character_studio.card_cli auto-tag alice base --tagger "python tagger.py {image}"
  ```
- Append or replace tags in bulk (defaults to all images in the subset):
  ```bash
  python -m modules.runtime.character_studio.card_cli edit-tags alice base --append "looking_at_viewer"
  python -m modules.runtime.character_studio.card_cli edit-tags alice base --replace "alice_tok, portrait"
  ```

## Training packs and trainer wrapper
- Export a portable zip containing the dataset and `training_config.json`:
  ```bash
  python -m modules.runtime.character_studio.card_cli export-training alice
  ```
- Invoke an external trainer (e.g., kohya-ss). Configure `CHAR_STUDIO_TRAINER_CMD` with placeholders `{config}`, `{dataset}`, and `{output}`:
  ```bash
  CHAR_STUDIO_TRAINER_CMD="bash train.sh --config {config} --output {output}"
  python -m modules.runtime.character_studio.card_cli train alice
  ```
  When a LoRA file appears at the expected output path, the Character Card is updated with the path and default strength.

## Feedback directives (deterministic)

`apply_feedback_to_character` in `models.py` expects key/value directives separated by semicolons or new lines. Example:
```
anatomy_tags: freckles, bob cut; wardrobe: hoodie; nsfw_allowed: false; metadata.version: 1.0
```
Supported keys include `description`, `default_prompt_snippet`, `trigger_token`, `trigger_tokens`, `anatomy_tags`, `wardrobe`, `reference_images`, `nsfw_allowed`, and `metadata.<key>`.
