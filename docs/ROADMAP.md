# Roadmap

This roadmap outlines current capabilities and planned milestones for AI Installer across short-, mid-, and long-term horizons. It also highlights reliability/UX efforts, GPU/performance goals, automation/configuration targets, and model/content management expansions.

## Current capabilities
- Modular installer for Ubuntu 22.04 with prerequisite checks and optional package installation.
- GPU detection with NVIDIA driver prompt and CPU fallback for AMD/Intel.
- Desktop launcher and YAD-based menu for launching Stable Diffusion WebUI, KoboldAI, SillyTavern, and update routines.
- Model and LoRA download utilities with optional Hugging Face token support and pairing workflows.

## Short-term milestones (1–2 releases)
- Harden install flow: clearer prompts, better error messaging, and safer retries for canceled package installs.
- Improve GPU detection logs and expose guidance for AMD/Intel acceleration options.
- Streamline menu UX: clarify wording on update options, default paths, and pairing flows.
- Add sanity checks for required tools (aria2c/wget) and fallback mirrors for model downloads.
- Publish a quickstart for common model presets (e.g., SD1.5) and LoRA pairing examples.

## Mid-term milestones (quarterly)
- Expand automation: configurable non-interactive install profile for headless setups.
- Enhance update/self-update reliability with checksum verification and clearer rollbacks.
- Add GPU performance toggles (e.g., half-precision, xformers/DirectML flags when available) with safety checks.
- Broaden model management: curated model lists, optional gated content prompts, and per-frontend defaults.
- Improve logging and telemetry hooks (opt-in) to surface install/launch errors.

## Long-term milestones (6+ months)
- Unified configuration schema for installer, launchers, and content management with export/import support.
- Pluggable backend for model/LoRA sources (community mirrors, local NAS, enterprise registries).
- Automated dependency tuning per GPU family (NVIDIA/AMD/Intel) with adaptive defaults for performance vs. stability.
- Optional cloud/offline bundles for constrained environments.
- GUI polish and accessibility updates for the launcher experience.

## Feature wishlist
- One-click GPU benchmark and diagnostics page from the launcher.
- Improved proxy and cache support for large model downloads.
- Scheduled update checks with minimal-disruption prompts.
- Rich model/LoRA metadata (thumbnails, tags, version notes) in pairing flows.
- Preset sharing/import for model+LoRA combinations across machines.
- Integrated backup/restore for installer configuration and downloaded assets.

## Reliability and UX improvements
- More resilient download retries with resumable transfers and clearer progress indicators.
- Better validation for Hugging Face tokens and gated asset access before starting downloads.
- Contextual help links/tooltips in the launcher for each action.
- Safety rails around self-update and git operations to avoid local changes loss.

## GPU and performance goals
- Expose hardware-aware defaults (e.g., fp16, tensor cores, ROCm/oneAPI when supported).
- Provide toggles for memory-saving features (e.g., low VRAM modes) and document trade-offs.
- Surface per-frontend performance tips and optional benchmarking scripts.

## Automation and configuration targets
- Headless/CI-friendly install mode using preseeded answers or config file.
- Centralized config location with schema validation and backups before changes.
- Optional environment export to reproduce installs across machines.

## Model and content management expansions
- Curated, versioned model lists with validation of checksums and licenses.
- Smarter download scheduling (prioritize smaller assets first, queue background fetches).
- Better LoRA pairing UX with recent-history shortcuts and conflict detection.
- Hooks for custom storage locations (e.g., external drives) with free-space checks.

## Prompt Builder Module

### Phase 1 - Design + Skeleton
- Add a design document describing the Prompt Builder user flow, JSON schema, and integration points.
- Create a new module folder: `modules/prompt_builder/`.

### Phase 2 - Prompt Compiler Service
- Implement a service that accepts a structured `SceneDescription` JSON and returns:
  - `positive_prompt`
  - `negative_prompt`
  - `lora_calls` (e.g. `["<lora:name:0.8>", ...]`)
- The service should call an LLM (local or remote) via an abstraction layer.

### Phase 3 - UI Integration
- Add a Prompt Builder tab/panel to the AI Hub UI.
- Modes:
  - Quick Prompt: single text input plus model/style dropdowns.
  - Guided Scene Builder: fields for world, setting, mood, style, nsfw_level, camera, and multiple characters.
  - Character selection: each character slot can pick an existing Character Card or open Character Studio to create/edit one.
- Refine with feedback: add `apply_feedback_to_scene(scene_json, feedback_text)` that uses the LLM abstraction to adjust the `SceneDescription` JSON, recompile prompts, and re-send them to Stable Diffusion WebUI for another generation.

### Phase 4 - Stable Diffusion WebUI Integration
- Add configuration options for the Stable Diffusion WebUI API endpoint and defaults (model, steps, resolution).
- Add a "Send to WebUI" action that posts the generated prompt and negative prompt to the WebUI txt2img API.

### Phase 5 - Advanced
- Prompt history and favorites.
- Per model prompt presets.
- Deeper integration with Character Studio for auto suggesting LoRAs and trigger tokens.

## Character Studio Module

### Phase 1 - Character Cards
- Define a Character Card schema shared with Prompt Builder.
- Provide UI to create/edit character metadata, anatomy tags, NSFW flags, trigger token, default prompt snippet, and reference images.
- Refine character via feedback: add `apply_feedback_to_character(character_card, feedback_text)` using the LLM abstraction to adjust description, default prompt snippet, and anatomy tags, with a UI option to apply scene-level feedback permanently to the character.

### Phase 2 - Dataset Builder (SFW)
- Use Stable Diffusion WebUI API to generate SFW reference images based on Character Card data.
- Allow the user to select images that match the character and save them into a dataset folder.
- Auto generate training captions using the character's `trigger_token` and anatomy tags plus generic tags like 1girl, pose, clothing, and scene.

### Phase 3 - NSFW & Anatomy Checklist (opt in)
- Respect an `nsfw_allowed` flag on each Character Card.
- Provide an anatomy / coverage checklist for opt-in adult datasets (varied outfits and poses).
- For each checklist item, generate batches, allow selection, and caption using:
  - `trigger_token`
  - anatomy tags (for stable traits like physique, distinguishing features, or style cues)
  - state/pose/clothing tags (varied poses, wardrobe choices, camera angles, etc.).

### Phase 4 - Tagging UI
- Add a tagging interface to review and edit captions.
- Support auto tagging using either the original prompt and/or an external tagger.
- Allow bulk edits and corrections.

### Phase 5 - Training Pack + Trainer Wrapper
- Export a training dataset pack for the character, including images and caption files, plus a config file for an external LoRA trainer (e.g. kohya-ss).
- Optionally add a wrapper to invoke the trainer and track its logs.
- On successful training, copy the resulting LoRA file into the appropriate folder and update the Character Card with `lora_file` and `lora_default_strength`.
