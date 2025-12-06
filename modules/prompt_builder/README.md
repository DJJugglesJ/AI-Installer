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

## UI workflow

- `modules/prompt_builder/ui.sh` launches YAD panels:
  - **Quick Prompt** gathers the vibe (setting, mood, style, NSFW level, and quick extras) and emits a minimal `SceneDescription`.
  - **Guided Scene Builder** captures world, camera, style, NSFW level, extra elements, and multi-line character rows (`slot_id,character_id,role,override`).
- Scenes are written to `~/.cache/aihub/prompt_builder/scene_description.json` before being compiled to prompts.
- Compiled bundles are written to `~/.cache/aihub/prompt_builder/prompt_bundle.json` (or `PROMPT_BUNDLE_PATH` when set) so launcher scripts can reuse the latest prompts without re-entering data.

### CLI triggers

- Compile a saved scene JSON: `python -m modules.prompt_builder --scene /path/to/scene.json`
- Run the YAD UI panels: `bash modules/prompt_builder/ui.sh`
- Both flows write the compiled `PromptAssembly` to the bundle cache and print the payload to stdout.

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

- **WebUI**: `modules/run_webui.sh` reads the bundle cache (default `~/.cache/aihub/prompt_builder/prompt_bundle.json` or `PROMPT_BUNDLE_PATH`) and exports `PROMPT_BUILDER_POSITIVE`, `PROMPT_BUILDER_NEGATIVE`, and `PROMPT_BUILDER_LORAS` before launching `launch.py`.
- **KoboldAI / text backends**: `modules/run_kobold.sh` applies the same bundle loader so the environment includes the compiled prompts and LoRA list when the runtime starts.
- **SillyTavern**: `modules/pair_sillytavern.sh` loads the bundle and injects the prompt environment variables into generated launch scripts so paired backends can pick up the latest scene.

## Services and extension hooks

- **Compiler service**: `modules/prompt_builder/services.py` includes a `PromptCompilerService` placeholder that wraps compiler behavior and can be replaced with an RPC handler later.
- **UI integration hooks**: `UIIntegrationHooks` validates scenes and writes compiled bundles to disk so UI layers and launcher scripts have a stable place to read prompts.

## Development and next steps

- Implement the compiler to call LLM abstractions and character registries for enriched prompt generation.
- Wire launcher-specific adapters that translate `PromptAssembly` into concrete CLI flags or config files.
- Add unit tests for JSON validation and LoRA routing.
- Extend `__main__.py` to accept CLI arguments (`--scene path/to/scene.json`) once the compiler is functional.
