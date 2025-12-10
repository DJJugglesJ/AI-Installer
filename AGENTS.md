1. Project overview (for agents)

AI-Hub is a cross-platform AI tool manager and launcher. It:
Installs and runs tools like Stable Diffusion WebUI, KoboldAI, SillyTavern.
Manages models and LoRAs via manifests.
Provides runtime services such as Prompt Builder and Character Studio.
Exposes workflows through shell helpers, a Web Launcher, and CLI entrypoints.
You must respect the existing separation of concerns:

modules/shell/ – installation, environment checks, downloads, GPU detection, launch helpers (bash).
modules/runtime/ – Python runtime logic (Prompt Builder, Character Studio, Web Launcher backend, config/manifest helpers).
launcher/ – user-facing launch scripts and entrypoints (bash, PowerShell, Python).
manifests/ – JSON metadata for models, LoRAs, presets.
docs/ – human documentation (roadmap, quickstarts, architecture).
tests/ – unit and integration tests.

2. General behavior rules for codegen agents

When you modify this repository:
Preserve architecture
Do not collapse or merge modules/shell and modules/runtime.
Avoid moving scripts between shell and Python layers unless explicitly requested.
Keep Linux/WSL and Windows launchers separate but symmetrical where practical.
Prefer small, focused changes
Limit changes to the files directly related to the requested feature or fix.
Avoid broad refactors unless explicitly asked.
Maintain existing public interfaces unless there is a clear reason to change them.
Keep changes cross-platform
Do not introduce Linux-only behavior into Python runtime modules.
Windows support should use PowerShell or batch wrappers that call Python or WSL, not shell-only constructs.
Avoid hard-coding OS-specific paths; use pathlib in Python.
Maintain idempotency and safety
Installers and launchers should be safe to re-run without breaking existing setups.
Shell scripts must handle missing dependencies and failed commands with clear error messages.
Respect existing style
Use pathlib in Python for file paths.
Use dataclasses and type hints where they are already in use.
Keep naming conventions consistent (snake_case for Python, lower-case with underscores for scripts).

3. Shell helpers (modules/shell)

You may:
Add or modify shell scripts under modules/shell when explicitly requested.
Introduce new helpers for installation, GPU detection, logging, manifest browsing, or launcher actions.

You must:
Use set -euo pipefail and quote variables in new or modified shell scripts.
Keep scripts small and focused, called from higher-level entrypoints (menus, web launcher, Windows wrappers).
Avoid hard-coding distribution-specific commands unless guarded and documented.
Keep behavior idempotent (safe to re-run).

You must not:
Embed complex business logic that belongs in Python runtime modules.
Introduce interactive prompts into scripts intended for headless usage without flags or guards.

4. Python runtime modules (modules/runtime)

Python runtime modules are the core “agents” of the system:
modules/runtime/prompt_builder
modules/runtime/character_studio
modules/runtime/web_launcher
modules/runtime/config_service and related utilities

You may:
Add new functions, classes, and small modules to extend behavior.
Implement new agents for prompt compilation, feedback application, character refinement, tagging, and dataset operations.
Refactor internals for clarity and testability while preserving public interfaces.

You must:
Keep runtime modules free of OS-specific logic.
Treat all user-facing I/O as JSON or structured data, not arbitrary text blobs.
Validate inputs against existing models/validators where available.
Keep side effects limited and explicit (e.g., file writes only where clearly documented).
Ensure new runtime features can be exercised via CLI or Web Launcher with clear entrypoints.

You should avoid:
Introducing new heavy dependencies unless necessary.
Adding network calls directly in runtime agents; these should be abstracted and clearly documented if introduced.

5. Prompt Builder (modules/runtime/prompt_builder)

Prompt Builder is a structured, scene-first system for image prompts.

You may:
Extend or refine compiler.py, llm.py, models.py, and services.py.
Add helpers to support scene construction, history, presets, or integration with WebUI.

You must:
Accept and return structured data. Scene input must conform to the SceneDescription/model definitions in models.py.
Keep prompt compilation logic installer-neutral and frontend-agnostic (no direct HTTP calls to WebUI inside compiler/llm code).
Keep side effects minimal: prompt compilation should not write files or run processes.
Use llm.py as the abstraction layer if LLM calls are required, not embed calls ad-hoc throughout the module.
When adding new features (for example, feedback application):
Introduce well-named functions (for example, apply_feedback_to_scene(scene, feedback_text)).
Keep the function pure (no I/O) and return a modified scene dict or a structured error object.

6. Character Studio (modules/runtime/character_studio)

Character Studio manages Character Cards, datasets, tagging, and training packs.

You may:
Extend card_cli.py, models.py, dataset.py, tagging.py, and trainer.py.
Implement new dataset workflows or tagging tools.

You must:
Use the unified Character Card schema defined in models.py.
Keep CLI actions in card_cli.py thin, delegating core logic to other module functions.
Keep file I/O and directory operations localized and explicit (for example, dataset folder operations in dataset.py).
Ensure tagging/captioning helpers accept structured input and return structured results (for example, a list of tags or a caption string plus metadata).

If you add LLM-based captioning or tag suggestions:
Isolate these in clearly named functions or submodules.
Accept well-typed input (character card + image context) and return deterministic, testable structures where possible.
Do not perform downloads or network calls implicitly.

7. Web Launcher runtime (modules/runtime/web_launcher)

The Web Launcher runtime backs the HTTP server and static UI.

You may:
Add or modify endpoints (in server.py) to expose new runtime features.
Extend the mapping between HTTP routes and runtime modules.

You must:
Keep Web Launcher routes thin; they should call into existing runtime modules rather than re-implement logic.
Validate request payloads and return structured JSON with clear error fields.
Avoid embedding HTML or UI logic in Python; keep UI in static/ and expose data via JSON APIs.

8. Manifests (manifests/)

Manifests describe models, LoRAs, and presets.

You may:
Add keys to existing manifest entries when required by new features.
Introduce new manifest files if you define and document their schema.

You must:
Maintain JSON validity.
Keep manifest fields consistent with existing conventions (hash, size, tags, mirrors, suggested_frontends, etc.).
Update any validation logic or tests if you change manifest structure.

Do not:
Overload manifest entries with runtime state.
Perform large content migrations without updating docs and tests.

9. Docs, roadmap, and architecture

Files of interest:
docs/ROADMAP.md
docs/ (quickstarts, performance notes, shortcuts)
architecture.md (if present or added)

You may:
Update the roadmap when you add or complete features.
Adjust architecture documentation to match actual code structure.

You must:
Keep documentation consistent with the state of the code.
Avoid promising features that do not exist or removing references to features that still do.
Keep roadmap entries for Prompt Builder and Character Studio integrated into the single unified roadmap (no separate roadmap documents per module).

10. Tests (tests/ and module-specific tests)

You may:
Add or update tests when you add features or change behavior.
Create new test modules close to the code they cover (for example, under modules/runtime/prompt_builder/tests).

You must:
Favor small, targeted tests that validate the schemas and behavior of agents and runtime helpers.
Keep test data minimal and synthetic rather than large embedded fixtures.

11. Adding new “agents”

When you introduce a new agent-like component (for example, a new LLM-backed helper or structured processor):
Place the code under the appropriate modules/runtime/<module_name>/ directory.
Define clear input and output structures (prefer reuse of existing models).
Keep any side effects (file writes, process calls) separate from pure transformation logic where possible.
Add or update tests.

Update this agents.md file with:
Agent name
Location
Purpose
Expected input/output
Important constraints

12. Things to avoid

Avoid the following unless explicitly requested:
Large, repo-wide refactors of shell scripts or runtime modules.
Introducing heavy dependencies beyond what the project already uses.
Embedding user interface strings, HTML, or JavaScript logic into Python runtime code.
Collapsing or changing the high-level directory structure.
If you are unsure about a change that could affect multiple modules or platforms, prefer a minimal implementation and leave a clear TODO comment explaining the limitation.
