Roadmap

This roadmap summarizes current capabilities and planned milestones for AI-Hub using clear time horizons. Prompt Builder and Character Studio deliverables are integrated directly into the same plan to avoid fragmentation.

Current capabilities
- Shell-first, modular architecture: installer and launcher helpers live in `modules/shell`, with runtime schemas and utilities (Prompt Builder, Character Studio, manifest validation) in `modules/runtime`.
- Cross-platform installers: Linux and WSL are first-class, with native Windows wrappers (`.bat`/`.ps1`) that mirror shell flows and shared logging locations.
- Defensive installation and GPU handling: prerequisite checks, resumable downloads, structured logs, and GPU probes (NVIDIA/AMD/Intel/DirectML) with safe CPU fallbacks.
- Launcher coverage and parity: YAD desktop launcher plus a Web Launcher that shares install/update/launch flows, manifest browsing, and pairing workflows where implemented.
- Manifest and runtime validation: curated model/LoRA manifests with hashes, mirrors, and front-end hints; schemas validate manifests, Prompt Builder scenes, Character Cards, and LoRA metadata with structured errors.
- Quickstart defaults: updated presets for SD1.5/SDXL, GPU hints, and safer defaults for new users.
- Modular media agents: audio (TTS/ASR/voice profiles) and video (img2vid/txt2vid) runtime packages share a global registry and
  the common `Task` dataclass, with JSON CLIs and shell wrappers so the web launcher can discover and trigger them safely.
- Prompt Builder and Character Studio foundations: schema-defined scenes and cards, prompt compilation, and apply-feedback utilities available via runtime/CLI entrypoints.
- Guided Scene Builder UI: Web Launcher panels for world/setting/mood/camera/characters.

Near-term milestones (1–2 releases)
- Ship GPU diagnostics across CLI, menu, and Web UI (VRAM checks, driver details, ROCm/oneAPI/DirectML tips).
- Expand Web Launcher parity: finish any remaining gaps in manifest browsing, model/LoRA pairing flows, inline quickstart guidance, and clearer loading/error states.
- Harden download reliability with mirror health checks, checksums, resumable/offline bundles, and structured error reporting in the Web Launcher.
- Complete Windows launcher parity with `.bat`/`.ps1` wrappers for all shell helpers, WSL fallbacks, and unified logging semantics.
- Real LLM provider integrations for Prompt Builder/Character Studio (bring-your-own key, pluggable providers, clear error paths).
- Manifest editing and health checks: tag editing, checksum validation, metadata updates, refresh cadence, and health indicators across CLI and Web Launcher.
- Dataset review UI: dataset browser, tagging/caption review queues, and safer editing flows in the Web Launcher.

Mid-term milestones (quarterly)
- Expand headless automation with fully configurable install profiles, schema-validated config ingestion, reproducible exports, and remote-friendly Web Launcher operation.
- Strengthen self-update with checksum integrity and safe rollback for installers and launchers.
- Add GPU performance toggles (fp16, xformers, DirectML, medvram) with compatibility checks across NVIDIA/AMD/Intel and headless presets.
- Deepen curated model governance with licensing notes, version tracking, deprecation warnings, and parity between shell and Web UI workflows.
- Provide offline-capable Web Launcher bundles (prebuilt assets, cached schemas) for air-gapped or low-connectivity environments.
- Add Prompt Builder feedback-driven prompt adjustment, history/favorites, and Character Studio dataset generation with tagging/caption review (including optional NSFW paths gated by `nsfw_allowed`).
- Integrate Web Launcher send-to-WebUI for compiled prompts (txt2img) with result handling.

Long-term milestones (6+ months)
- Introduce unified configuration for installer, launcher, runtime services, and content management with import/export support.
- Offer pluggable backends for models and LoRAs (community mirrors, NAS, enterprise registries) plus advanced GPU tuning informed by benchmarks.
- Maintain accessibility and usability improvements across Web Launcher and desktop flows with device-friendly layouts and remote access.
- Deliver offline/cloud hybrid bundles for intermittent connectivity and curated governance for model provenance and lifecycle.
- Provide dataset-to-LoRA training exports (packaging, metadata, training config generation, trainer wrappers) and automated LoRA registration into manifests and Character Cards.
- Extend advanced prompting features: model-specific presets, LoRA suggestion logic, and Prompt Builder/Character Studio feedback loops.

Feature wishlist
- GPU benchmark page accessible from launcher or Web UI.
- Improved proxy and caching support for large model downloads.
- Scheduled update checks with minimal-disruption behavior.
- Rich model and LoRA metadata including thumbnails and version notes.
- Preset sharing/import for prompt, model, and LoRA combinations.
- Backup and restore for installer configuration, manifests, and downloaded assets.
- Conflict detection for LoRA/model incompatibilities in pairing flows.
- Reliability and UX improvements: resilient downloads with progress, Hugging Face token validation, contextual help, and safety rails around self-update/git.
- GPU and performance goals: hardware-aware defaults for fp16/xformers/DirectML/ROCm/oneAPI, low-VRAM modes, and optional benchmarks.
- Automation and configuration targets: CI-friendly unattended installs, centralized config with validation and backups, environment export/import.
- Model and content management expansions: versioned curated lists with checksums, smarter download scheduling, improved LoRA pairing history, and external storage with free-space checks.
