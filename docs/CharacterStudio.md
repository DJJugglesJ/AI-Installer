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
- `trigger_token` (unique token to be used in training captions and prompts, e.g., `"baileen_oc"`)
- `anatomy_tags` (array of generic tags such as `"1girl"`, `"large_breasts"`, `"puffy_nipples"`, `"pale_areola"`, `"freckles"`, `"pale_skin"`)
- `lora_file` (optional path or filename)
- `lora_default_strength` (optional float)
- `reference_images` (array of file paths)

## Dataset folder structure
- `datasets/characters/{character_id}/base/`
- `datasets/characters/{character_id}/nsfw/topless/`
- `datasets/characters/{character_id}/nsfw/nude/`

## Captioning strategy
- Every caption must include `trigger_token` plus relevant `anatomy_tags` for stable traits.
- Add state/pose/clothing/scene tags on top. For example:
  - `"baileen_oc, 1girl, topless, large_breasts, puffy_nipples, pale_areola, freckles, pale_skin, standing, looking_at_viewer"`
- Do not use artificial tags like `"Baileen topless"` as the only identifier.

## Integration with Prompt Builder
- Prompt Builder looks up Character Cards by `character_id`.
- It injects `trigger_token` and `default_prompt_snippet` into the positive prompt.
- If `lora_file` is present, it prepends a LoRA call like `"<lora:Baileen_v1:0.9>"`.
- Both modules should load Character Cards via a shared registry, not hard-coded files, to stay in sync.
