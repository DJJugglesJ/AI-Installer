# AI Hub Architecture

## 1. Overview
AI Hub is a modular AI workstation that orchestrates local and remote AI systems behind a unified interface. The project is split into two primary components:

1. **Installer Layer** – prepares the environment, installs dependencies, and exposes menu-driven launchers.
2. **Runtime Layer** – Python modules that deliver higher-level logic, prompt tooling, model workflows, and data management.

Directory layout after the recent reorganization:
- `modules/runtime/` – **Python package root** (`modules/runtime/__init__.py`) that exposes all runtime namespaces. Every
  runtime component is imported or executed via `modules.runtime` (for example, `python -m modules.runtime.prompt.builder`).
- `modules/shell/` – **installer and launcher scripts** for POSIX and Windows. These helpers own environment detection,
  dependency installs, and runtime entrypoints while delegating business logic to the Python package.

Common handoffs after the reorg:
- Install/update flows call module-qualified entrypoints, e.g., `python -m modules.runtime.install.entrypoint --manifest
  manifests/base.json`, instead of file paths like `python modules/runtime/install/entrypoint.py`.
- Launchers call shell helpers such as `modules/shell/run_webui.sh` or `modules/shell/run_comfyui.sh`. Each helper wraps
  runtime services through module-qualified commands (for example, `python -m modules.runtime.webui.service --host 0.0.0.0`).
- Cross-layer calls reference the new roots explicitly: shell scripts treat `modules/runtime` as the Python package root,
  while Python code locates installer assets through `modules/shell` (for example, `Path(__file__).parents[2] / "modules"
  / "shell" / "install.sh"`).

The runtime and installer layers share only well-defined interfaces: shell scripts invoke Python entrypoints via module paths under `modules/runtime`, while Python code must reference shell assets using relative paths through `modules/shell`. Avoid hardcoded absolute paths so the project remains relocatable.

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
- Callers reference the reorganized roots explicitly:
  - **Shell/installer → runtime:** `python -m modules.runtime.prompt.cli --scene scenes/example.json`
  - **Runtime → shell helper:** `subprocess.run([repo_root / "modules" / "shell" / "run_webui.sh"], check=True)`
  - **Launchers → services:** menu or web launchers point at shell wrappers (e.g., `modules/shell/run_comfyui.sh`) which then
    execute the correct runtime module without depending on file layouts.
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

## 7. Web UI Front End

### Hosting model
- The web UI is a static, compiled frontend (e.g., React/Vite or similar) that is served by a lightweight HTTP layer inside the runtime stack so it can run headless on servers, WSL, or desktop Linux without requiring a local browser process to be installed by the installer scripts.
- Static assets live under a dedicated `modules/runtime/webui_frontend/` build output, with the Python runtime exposing them through the same process that serves JSON APIs. This keeps the UI deployable via `python -m modules.runtime.<service>` and compatible with launcher scripts that already start runtime daemons.
- A reverse-proxy-friendly binding (127.0.0.1 by default, configurable host/port) allows the UI to be tunneled over SSH or proxied behind Caddy/NGINX for remote access.

### Runtime integration
- UI panels communicate with runtime modules via JSON APIs that wrap existing entrypoints rather than duplicating logic. Prompt Builder views call the Prompt Builder service to compile scenes, fetch presets, and send prompts to Stable Diffusion WebUI; Character Studio views call the Character Studio APIs for card CRUD, dataset helpers, and LoRA metadata.
- Launcher/install actions are exposed as API endpoints that shell out to the same `modules/shell` scripts the YAD/menu flows invoke, ensuring identical side effects and logs while enabling non-desktop execution.
- Shared schemas (SceneDescription, Character Card) are versioned in `modules/runtime` and imported by both the backend handlers and the frontend TypeScript types to keep compatibility across releases.

### Relationship to existing menus
- The YAD/menu flows remain available as a compatibility layer but are gradually replaced by the web UI for cross-platform consistency (Linux desktop, WSL, headless servers). Both surfaces call the same runtime APIs so feature delivery remains unified.
- Desktop launchers can open the local web UI in the default browser instead of YAD, while command-line users can access the same actions via HTTP or CLI wrappers.
- The web UI adds new affordances such as remote access, responsive layouts, and deeper module integrations (Prompt Builder + Character Studio) without forcing users to install desktop widget toolkits.

### Web launcher and manifest surface
- A dedicated web-based launcher surface runs off the same lightweight HTTP server that serves compiled frontend assets, keeping all flows available on systems without desktop widget toolkits (including macOS/Windows) and WSL/headless Linux.
- Launcher controls call existing shell helpers for install/update/launch actions through backend API handlers so logs, exit codes, and side effects remain identical to YAD dialogs.
- Manifest browsing uses the same runtime metadata readers that power CLI flows, exposing search/filter/download triggers from the web UI while reusing checksum validation and hooks for runtime module updates.
- OS integration favors opening the local browser pointing at the server host/port instead of spawning YAD; on Linux the YAD dialogs can be retained as a fallback, while non-Linux platforms rely exclusively on the web surface to deliver equivalent flows.
- Backend handlers stay platform-aware: they leverage `modules/shell` scripts where available, provide WSL-aware bridges on Windows, and keep schema parity with runtime modules so new hooks (e.g., prompt tools) can be exposed without diverging UX between web and desktop dialogs.

## 8. Summary

The installer layer prepares and launches the environment, while runtime modules deliver AI Hub functionality. Prompt Builder and Character Studio form the core runtime capabilities, interacting with shared data and configuration layers. The architecture emphasizes abstraction, multi-backend support, and modular expansion so the project can grow without being tied to specific hardware, users, or content types.
