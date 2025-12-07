# AI Hub Architecture

## 1. Overview
AI Hub is a modular AI workstation that orchestrates local and remote AI systems behind a unified interface. The project is split into two primary components:

1. **Installer Layer** – prepares the environment, installs dependencies, and exposes menu-driven launchers.
2. **Runtime Layer** – Python modules that deliver higher-level logic, prompt tooling, model workflows, and data management.

Directory layout after the recent reorganization:
- `modules/runtime/` – all Python packages and shared runtime utilities.
- `modules/shell/` – installer and launcher scripts that orchestrate downloads, env setup, and entrypoints.

The runtime and installer layers share only well-defined interfaces: shell scripts invoke Python entrypoints via module paths under `modules/runtime`, while Python code must reference shell assets using relative paths through `modules/shell` (e.g., `Path(__file__).parents[2] / "modules" / "shell" / "install.sh"`). Avoid hardcoded absolute paths so the project remains relocatable.

AI Hub is designed to unify tools and services such as:
- Stable Diffusion WebUI or ComfyUI for image and video generation
- Text-generation LLMs running locally or through local gateways
- LoRA and model management utilities
- Prompt-building helpers
- Optional character management and training dataset tooling

## 2. Architecture Layers

### A. Installer Layer (Shell-Based)
The installer layer is implemented primarily in shell scripts (for example, `install.sh`, `aihub_menu.sh`, and scripts under `modules/shell/`). It is responsible for:
- Detecting operating system details, GPU/driver compatibility, Python environment, and package dependencies
- Ensuring the target environment is ready (native Ubuntu 22.04 or Windows with WSL2 + Ubuntu enabled) before continuing
- Installing or updating AI tools such as Stable Diffusion WebUI, ComfyUI, and local text LLM backends
- Creating desktop launchers and quick-access menus
- Storing manifests for model downloads and tool configuration
- Keeping business logic for prompt building, character workflows, and LoRA training out of the installer scripts

Installer scripts should call into Python by executing module entrypoints (e.g., `python -m modules.runtime.<package>`) rather than importing files directly, and should refer to sibling assets through relative paths rooted at the repository (e.g., `"$(dirname "$0")/../modules/runtime"`). The installer prepares the system and launches tools but does not execute core AI Hub runtime logic.

#### Windows counterparts for launchers and hardware checks
- Provide `.bat` wrappers plus `.ps1` scripts that mirror the naming and entrypoints of the existing shell helpers (for example, `run_webui.ps1` alongside `modules/shell/run_webui.sh`).
- Place Windows helpers under `modules/shell/windows/` to keep parity with the Linux layout while isolating platform-specific logic; keep logging format consistent with `modules/shell/logging.sh` so downstream tooling can parse either platform.
- For GPU probing, prefer PowerShell implementations that call `Get-WmiObject`/`Get-CimInstance` and detect NVIDIA/AMD/Intel adapters; fall back to WSL detection when available to reuse `modules/shell/detect_gpu.sh` for parity.
- Use PowerShell Core when present and default to Windows PowerShell if unavailable; `.bat` files act as thin shims that invoke the `.ps1` scripts with execution policy bypassed and propagate exit codes.

### B. Runtime Layer (Python Modules)
The runtime lives under `modules/runtime/` and contains all domain logic for AI Hub. It is responsible for:
- Prompt Builder: compiling structured scenes into prompts
- Character Studio: managing character cards, dataset preparation, tagging, and LoRA training workflows
- Model / LoRA Manager: downloads, metadata, sorting, and activation sets
- Future planned modules such as prompt helper UIs, API orchestrators, or tagging services

Runtime modules take structured JSON input (scene descriptions, character cards, settings) and communicate with AI backends including:
- Stable Diffusion WebUI APIs
- ComfyUI workflows
- Local LLMs for prompt compilation and feedback refinement

Python packages should import within `modules.runtime` namespaces (for example, `from modules.runtime.prompt import builder`) so that entrypoints remain stable when invoked from shell. When a runtime component needs to trigger installers or launchers, it should shell out to the appropriate script under `modules/shell` using repository-relative paths constructed via `Path(__file__).parents` rather than assuming absolute locations.

Modules should be backend-agnostic via abstraction layers so image generators, LLMs, and taggers can be swapped without rewriting core logic.

### C. Data & Configuration Layer
Persistent data and configuration live outside the code paths and may include:
- `manifests/` for model lists, LoRA catalogs, and default settings
- `filters/` for optional keyword filters or metadata maps
- `datasets/` for generated character datasets used in LoRA training
- `characters/` (optional) for JSON Character Cards
- `config/` for user settings, API endpoints, and feature toggles

Design principles:
- Avoid hardcoded paths inside modules
- Keep user-editable configs separate from code
- Support clean import/export of structured data

## 3. Core Runtime Modules

### A. Prompt Builder Module
Lifecycle:
1. Accepts a structured SceneDescription JSON with fields for world, setting, style, mood, `nsfw_level`, camera, character references, and extra scene elements
2. Uses a local or remote LLM to compile the structured data into a positive prompt, negative prompt, and LoRA call list
3. Supports feedback refinement through `apply_feedback_to_scene(scene_json, feedback_text)` that adjusts the SceneDescription via the LLM and regenerates prompts
4. Can send prompts to Stable Diffusion WebUI or other backends through APIs

### B. Character Studio Module
Responsibilities:
- Manage Character Cards defined in JSON
- Provide UI/CLI tooling to edit identity details, descriptions, default prompt snippets, optional trait tags, NSFW capability flags, and trigger tokens for LoRA training
- Offer dataset-building capabilities: generate batches from image backends, allow selection of samples, and auto-generate captions using character information with generic tags
- Provide tagging interfaces and automation for reviewing, auto-tagging, and bulk edits
- Support LoRA training workflows: export dataset structures and configs, optionally wrap external trainers, and save resulting LoRA files while updating Character Card metadata
- Enable character-level feedback refinement through `apply_feedback_to_character(card_json, feedback_text)` to adjust descriptions, prompt snippets, and trait tags using LLM output

### C. Model & LoRA Manager Module
Responsibilities:
- Handle model metadata, versioning, updates, sorting, tagging, and grouping
- Provide activation sets for applying multiple LoRAs
- Integrate with Prompt Builder so LoRA metadata can surface in user interfaces

## 4. Interaction Between Modules

- Character Studio defines characters and optional LoRAs, stored as JSON and model files
- Prompt Builder reads Character Cards and scene JSON to compile prompts
- Runtime modules communicate with image generation backends via structured API calls
- Installer scripts in `modules/shell` launch or update these services and then call into Python entrypoints under `modules.runtime` for orchestration and business logic
- Data and configuration layers hold persistent metadata, datasets, models, LoRAs, and settings
- Modules remain self-contained yet interoperable through shared schemas

## 5. Backend Abstractions

AI Hub avoids hardcoded dependencies by relying on abstraction layers:
- **LLM abstraction:** runtime modules request LLM output without binding to a specific model
- **Image-generation abstraction:** backends like WebUI, ComfyUI, or others can be swapped with minimal change
- **Tagging abstraction:** auto-captioning and tagging tools can be replaced without altering core logic

## 6. Extensibility Principles

- Keep modules small, focused, and replaceable
- Add new capabilities via new modules rather than overloading existing ones
- Use JSON schemas as the shared contract between modules
- Avoid embedding user-specific examples or explicit content in repository documentation
- Keep example prompts neutral (e.g., "example character", "fantasy setting")

## 7. Summary

The installer layer prepares and launches the environment, while runtime modules deliver AI Hub functionality. Prompt Builder and Character Studio form the core runtime capabilities, interacting with shared data and configuration layers. The architecture emphasizes abstraction, multi-backend support, and modular expansion so the project can grow without being tied to specific hardware, users, or content types.
