# Character Studio

## Role
Character Studio manages the character lifecycle for prompting and LoRA training. It shares Character Cards with Prompt Builder through a common registry to ensure consistent metadata and trigger tokens.

## Character Card schema
- `id` (string key)
- `name`
- `age`
- `nsfw_allowed` (boolean)
- `description` (long text)
- `default_prompt_snippet` (short SD-friendly description)
- `trigger_token` (unique token to be used in training captions and prompts, e.g., `"char_a_token"`)
- `anatomy_tags` (array of appearance tags such as `"humanoid"`, `"freckles"`, `"athletic_build"`, `"short_stature"`)
- `lora_file` (optional path or filename)
- `lora_default_strength` (optional float)
- `reference_images` (array of file paths)

## Dataset folder structure
- `datasets/characters/{character_id}/base/`
- `datasets/characters/{character_id}/nsfw/variant_a/`
- `datasets/characters/{character_id}/nsfw/variant_b/`

## Captioning strategy
- Every caption must include `trigger_token` plus relevant `anatomy_tags` for stable traits.
- Add state/pose/clothing/scene tags on top. For example:
  - `"char_a_token, character portrait, short_stature, freckles, casual_outfit, standing, looking_at_viewer"`
- Avoid relying on improvised names as identifiers; keep captions consistent with the trigger token and descriptive tags.

## Integration with Prompt Builder
- Prompt Builder looks up Character Cards by `character_id`.
- It injects `trigger_token` and `default_prompt_snippet` into the positive prompt.
- If `lora_file` is present, it prepends a LoRA call like `"<lora:CharacterA_v1:0.9>"`.
- Both modules should load Character Cards via a shared registry, not hard-coded files, to stay in sync.

## Character Feedback Refinement
- Users can give persistent feedback to refine a character's definition (e.g., change height, body type, or species).
- `apply_feedback_to_character(character_card, feedback_text)`:
  - **Inputs:** current Character Card JSON and a feedback string.
  - **Output:** updated Character Card JSON.
  - **Behavior:** uses the LLM abstraction to adjust `description`, `default_prompt_snippet`, and `anatomy_tags` so the character better matches the feedback.
- Scene-level feedback can optionally be applied permanently to the Character Card through this pathway.
