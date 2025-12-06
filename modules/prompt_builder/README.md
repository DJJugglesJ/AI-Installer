# Prompt Builder Module

This module introduces a structured, scene-first workflow for composing AI prompts that can be surfaced across the existing launchers (e.g., WebUI, KoboldAI, SillyTavern). The goal is to accept JSON payloads that describe the desired scene, compile those into positive/negative prompt strings, and orchestrate optional LoRA calls while remaining installer-neutral.

## User flows

1. **Scene capture**
   - A UI presents fields for world, setting, mood, style, camera, and safety level.
   - Users add characters by selecting existing Character Cards or supplying trigger tokens, and optionally add extra elements (props, weather, time-of-day cues).
   - The UI posts a `SceneDescription` JSON payload to the Prompt Builder compiler service.

2. **Prompt compilation**
   - The compiler enriches characters (via Character Card registry when available), blends user-provided snippets, and synthesizes positive/negative prompts.
   - LoRA calls are derived from character metadata and explicit user selections, producing a `PromptAssembly` response.

3. **Launcher hand-off**
   - Launchers (shell scripts or UI buttons) consume the `PromptAssembly` output.
   - Positive prompts feed Stable Diffusion style backends (e.g., `modules/run_webui.sh`).
   - Negative prompts plug into the same pipelines for safety and content shaping.
   - LoRA calls are passed through to existing LoRA selectors (e.g., `modules/install_loras.sh`, `modules/select_lora.sh`) without modifying installer logic.

## JSON schema: `SceneDescription`

```json
{
  "world": "Optional<string>",
  "setting": "Optional<string>",
  "mood": "Optional<string>",
  "style": "Optional<string>",
  "nsfw_level": "Optional<string>",
  "camera": "Optional<string>",
  "characters": [
    {
      "slot_id": "string",
      "character_id": "string",
      "role": "Optional<string>",
      "override_prompt_snippet": "Optional<string>"
    }
  ],
  "extra_elements": ["string", "string", "..."]
}
```

See `modules/prompt_builder/models.py` for the Python data models that mirror this shape.

## Integration points with existing launchers

- **WebUI**: Adapt `modules/run_webui.sh` to accept compiled prompts via environment variables or a temporary JSON file. The Prompt Builder should generate a `PromptAssembly` payload that the launcher reads before spawning the WebUI.
- **KoboldAI / text backends**: Feed the positive prompt as the initial prompt seed and use the negative prompt for safety filters. LoRA calls map to any LoRA-aware startup flags currently exposed in `modules/run_kobold.sh`.
- **SillyTavern**: Expose a small client hook that writes the compiled prompt bundle to `modules/prompt_builder/tmp/prompt.json` (or a similar cache) that SillyTavern scripts can ingest before calling `pair_sillytavern.sh`.

## Services and extension hooks

- **Compiler service**: `modules/prompt_builder/services.py` includes a `PromptCompilerService` placeholder that wraps compiler behavior and can be replaced with an RPC handler later.
- **UI integration hooks**: `UIIntegrationHooks` defines stub methods (`preflight_scene`, `publish_prompt`) for UI layers to coordinate validation and delivery.

## Development and next steps

- Implement the compiler to call LLM abstractions and character registries for enriched prompt generation.
- Wire launcher-specific adapters that translate `PromptAssembly` into concrete CLI flags or config files.
- Add unit tests for JSON validation and LoRA routing.
- Extend `__main__.py` to accept CLI arguments (`--scene path/to/scene.json`) once the compiler is functional.
