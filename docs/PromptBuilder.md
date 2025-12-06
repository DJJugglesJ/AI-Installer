# Prompt Builder

## Problem statement
Users often face "blank prompt syndrome" when trying to craft Stable Diffusion prompts, and stacking LoRAs with the correct syntax is error-prone.

## Solution overview
Prompt Builder converts human-friendly scene descriptions into Stable Diffusion prompts and negative prompts using a shared schema and Character Cards. It coordinates with Character Studio so both modules rely on the same Character Card registry rather than duplicating schema details.

## SceneDescription JSON schema
- `world` (string)
- `setting` (string)
- `mood` (string)
- `style` (string)
- `nsfw_level` (enum: `none`, `suggestive`, `explicit`)
- `camera` (string, e.g. `close_up`, `medium_shot`, `wide_shot`)
- `characters` (array of objects):
  - `slot_id`
  - `character_id` (links to Character Card)
  - `role` (optional short description)
  - `override_prompt_snippet` (optional manual tweak)
- `extra_elements` (array of strings for secondary scene details)

## Prompt Compiler Service API
- **Input:** `SceneDescription` JSON plus optional global defaults.
- **Output JSON:**
  - `positive_prompt` (string)
  - `negative_prompt` (string)
  - `lora_calls` (array of strings like `"<lora:Name:0.8>"`)

## Integration notes
- The compiler should load Character Cards through a shared registry, not hard-coded data.
- Prompt Builder and Character Studio must rely on the same Character Card definition to avoid schema drift.
- The service should call an LLM (local or remote) via a pluggable abstraction layer to convert `SceneDescription` into prompts.

## Scene Feedback Refinement
- Users can enter natural language feedback after a generation (e.g., "make the character shorter and more petite").
- `apply_feedback_to_scene(scene_json, feedback_text)`:
  - **Inputs:** current `SceneDescription` JSON and a feedback string.
  - **Output:** updated `SceneDescription` JSON.
  - **Behavior:** calls the same LLM abstraction to adjust fields (character traits, style, mood, etc.), then passes the updated JSON back to the prompt compiler for regeneration.
- Refinement is per scene by default and does not automatically change Character Cards.
