Roadmap

This roadmap outlines current capabilities and planned milestones for AI-Hub across short-, mid-, and long-term horizons. All module-specific items, including Prompt Builder and Character Studio, are integrated directly into the roadmap to eliminate fragmentation.

Current capabilities

Modular installer architecture with modules/shell for install/update/launch helpers and modules/runtime for schemas, Prompt Builder, Character Studio, and manifest utilities.

Cross-platform support including Linux, WSL2, and initial native Windows parity via .bat/.ps1 launchers, GPU probes, and consistent logging locations.

Hardened installer with prerequisite checks, safe retries, download resumption, GPU detection (NVIDIA/AMD/Intel/DirectML/CPU fallback), and detailed structured logs.

YAD-based launcher menu for Stable Diffusion WebUI, KoboldAI, SillyTavern, model downloads, LoRA management, and self-update flows.

Early Web Launcher backend exposing install, update, manifest browsing, and runtime endpoints over HTTP.

Curated model and LoRA manifests including size, hashes, tags, front-end suggestions, mirrors, and structured validation to catch malformed entries.

Runtime validation of manifests, Prompt Builder scene descriptions, Character Cards, and LoRA metadata with structured error messages.

Updated quickstarts surfacing SD1.5/SDXL presets, GPU hints, and improved launcher defaults for new users.

Short-term milestones (1–2 releases)

Add a GPU health and diagnostics action (CLI, menu, and Web UI) including VRAM checks, driver info, and ROCm/oneAPI/DirectML hints.

Improve parity between YAD menu and Web Launcher for manifest browsing, LoRA/model pairing workflows, inline descriptions, and default selections matching headless configuration.

Improve download reliability with mirror health checks, checksum diffs, offline bundles, and structured error reporting in the Web Launcher.

Integrate quickstart guidance directly into the Web Launcher for new users.

Finalize Windows launcher parity by completing .bat/.ps1 equivalents for all shell helpers, adding WSL fallbacks and shared logging semantics.

Deliver a cross-platform Web Launcher interface that exposes install, update, launch, and manifest maintenance operations and provides clear loading/error states.

Expand manifest browser with support for tag editing, checksum validation, and metadata updates.

Add a curated model and LoRA browser in both CLI and Web UI with refresh cadence, mirror health indicators, and one-click installs.

Implement unified schema definitions for Prompt Builder and Character Studio models within modules/runtime with consistent validation rules. (Prompt Builder / Character Studio)

Implement core prompt compilation: structured SceneDescription JSON input producing positive_prompt, negative_prompt, and LoRA call list, using an LLM abstraction layer. (Prompt Builder)

Add Guided Scene Builder UI panels (world, setting, mood, camera, characters) and Quick Prompt mode to the Web Launcher. (Prompt Builder)

Implement Character Card editing UI (anatomy tags, wardrobe defaults, trigger tokens, reference images, and nsfw_allowed flag). (Character Studio)

Implement apply-feedback functions that allow LLM-assisted refinement of Scene Descriptions and Character Cards. (Prompt Builder / Character Studio)

Mid-term milestones (quarterly)

Expand headless automation: fully configurable install profiles, schema-validated config ingestion, and reproducible environment exports.

Enhance update/self-update reliability with checksums, integrity checks, and safe rollback options.

Add GPU performance toggles (fp16, xformers, DirectML, medvram) with compatibility checks for NVIDIA, AMD, and Intel.

Expand curated model management with licensing notes, version tracking, deprecation warnings, and parity between shell and Web UI workflows.

Improve logging and optional telemetry hooks (opt-in) for install/launch diagnostics across platforms.

Deliver full native Windows installation and launcher parity using PowerShell and batch wrappers, enabling Windows users to operate without WSL unless necessary.

Promote Web Launcher as the primary user interface, with a CLI fallback and remote access capability for headless servers.

Add offline-capable Web Launcher bundles (prebuilt assets, cached schemas) for air-gapped systems.

Add structured Prompt Builder feedback-driven prompt adjustment and prompt history/favorites. (Prompt Builder)

Implement character dataset generation for SFW reference sets using WebUI API, including image selection and auto-captioning using trigger tokens and core tags. (Character Studio)

Add optional NSFW dataset workflows gated by nsfw_allowed, including anatomy/coverage checklists, structured batch generation, selection, and captioning. (Character Studio)

Add a tagging/caption-review UI for dataset refinement with bulk edits and auto-tagging support. (Character Studio)

Add Web Launcher integration for sending compiled prompts directly to Stable Diffusion WebUI txt2img endpoints with result handling. (Prompt Builder)

Long-term milestones (6+ months)

Introduce a unified configuration schema for installer, launcher, runtime services, and content management with import/export support.

Provide pluggable backend sources for models and LoRAs (community mirrors, local NAS, enterprise registries).

Add automated GPU tuning that adapts installer defaults based on detected hardware and benchmark results.

Deliver accessibility and usability improvements across the Web Launcher and desktop flows, including clearer navigation and device-friendly layouts.

Expand the Web Launcher into a consolidated workspace with optional third-party panels (ComfyUI graph viewer, training dashboards, telemetry tools).

Provide offline/cloud hybrid bundles for environments with intermittent connectivity.

Add dataset-to-LoRA training export including dataset packaging, metadata, training config generation, and an optional trainer wrapper (e.g. kohya). (Character Studio)

Add automated LoRA registration into manifests and Character Cards after training completes. (Character Studio)

Add advanced model-specific prompting presets and LoRA suggestion logic for characters and scenes. (Prompt Builder)

Feature wishlist

GPU benchmark page accessible from launcher or Web UI.

Improved proxy and caching support for large model downloads.

Scheduled update checks with minimal-disruption behavior.

Rich model and LoRA metadata including thumbnails and version notes.

Preset sharing/import for prompt, model, and LoRA combinations.

Backup and restore for installer configuration, manifests, and downloaded assets.

Conflict detection for LoRA/model incompatibilities in pairing flows.

Reliability and UX improvements

More resilient download retries with clearer progress reporting.

Improved Hugging Face token validation before downloading gated assets.

Contextual help links or tooltips throughout launcher and Web UI.

Safety rails around self-update and git operations to prevent loss of local changes.

GPU and performance goals

Hardware-aware default settings for fp16, xformers, DirectML, ROCm, and oneAPI.

Low-VRAM configurations with documented trade-offs.

Optional benchmark scripts with guidance per frontend.

Automation and configuration targets

CI-friendly, fully unattended install mode with preseeded answers.

Centralized configuration directory with schema validation and automatic backups.

Environment export/import to reproduce installs across machines.

Model and content management expansions

Versioned curated model lists with checksums and metadata validation.

Smarter download scheduling/queuing prioritizing smaller or required files.

Improved LoRA pairing flows with conflict detection and history recall.

Support for external or custom storage locations with free-space checks.
