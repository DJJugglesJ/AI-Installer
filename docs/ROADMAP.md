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
