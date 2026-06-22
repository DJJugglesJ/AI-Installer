# AI-Hub

> **One command to build your local AI cockpit. One launcher to run it. One hub to grow it.**

AI-Hub is the control room for self-hosted creative and conversational AI: a cross-platform installer, launcher, and runtime toolkit that helps you bootstrap Stable Diffusion WebUI, KoboldAI, SillyTavern, models, LoRAs, prompts, and character workflows without turning setup into a side quest.

## The vision

AI tools are powerful, but the ecosystem can feel scattered: every frontend has different install steps, GPU flags, model folders, launch scripts, and update rituals. AI-Hub brings those pieces together into a predictable, approachable workspace where makers can install once, launch from one place, and keep building.

- **From zero to running:** guided installers, headless automation, resilient downloads, logs, and shortcuts.
- **From scripts to workflows:** Web Launcher actions connect shell helpers, manifests, and Python runtimes through structured JSON APIs.
- **From prompt ideas to reusable systems:** Prompt Builder turns scene descriptions into structured prompt bundles and supports deterministic feedback loops.
- **From character concepts to production packs:** Character Studio organizes cards, datasets, captions, tags, and training-ready assets.
- **From one machine to many setups:** Linux, WSL2, and Windows launchers stay separate, safe, and symmetrical where practical.

## What you get

| Area | What AI-Hub does |
| --- | --- |
| **Install & launch** | Bootstraps Stable Diffusion WebUI, KoboldAI, SillyTavern, ComfyUI, dependencies, shortcuts, and logs. |
| **Web Launcher** | Provides the main browser-based UX at `http://127.0.0.1:3939` for installs, manifests, prompts, characters, and job logs. |
| **Prompt Builder** | Compiles structured scene JSON into prompt output, LoRA call lists, history, and prompt bundles. |
| **Character Studio** | Manages character cards, dataset prep, captioning/tagging helpers, and registry views. |
| **Manifest-driven models** | Uses curated JSON metadata for predictable model and LoRA downloads. |
| **Cross-platform wrappers** | Keeps Linux/WSL bash and Windows PowerShell/batch launchers aligned without mixing platform-specific concerns. |

## Start here

```bash
chmod +x install.sh
./install.sh
```

Then open the Web Launcher with:

```bash
./launcher/linux/start_web_launcher.sh
```

Windows users can start from PowerShell instead:

```powershell
.\install.ps1
.\launcher\windows\start_web_launcher.ps1
```

Need an unattended setup? Use the headless flow:

```bash
./install.sh --headless --install webui --gpu nvidia
```

## Why it matters

AI-Hub is designed around a simple promise: **local AI should feel like a workspace, not a pile of fragile setup notes.** Installers stay idempotent, runtime logic stays schema-first, manifests stay transparent, and launchers stay thin. That separation makes the project easier to trust, debug, extend, and run again tomorrow.

## Explore the hub

1. **Install** a target app or model from the Web Launcher.
2. **Run** Stable Diffusion WebUI, KoboldAI, SillyTavern, or supporting services with GPU-aware defaults.
3. **Build prompts** from structured scenes and refine them with deterministic feedback.
4. **Manage characters** with cards, datasets, tags, captions, and training-pack workflows.
5. **Automate** repeatable setup with headless configs and direct CLI wrappers.

---

# Complete project reference

The original detailed README content is preserved below for setup, architecture, usage, troubleshooting, and contribution details.

AI-Hub is a cross-platform installer, launcher, and runtime toolkit for creative and conversational AI workflows. It ships safe-by-default shell helpers, schema-driven Python runtimes, curated manifests, and lightweight launchers so newcomers can get Stable Diffusion, KoboldAI, and SillyTavern running with predictable results.

- **Platforms:** Linux (desktop/headless) with first-class WSL2 and Windows launcher parity.
- **Focus:** Repeatable installs, GPU-aware defaults, resilient downloads, and transparent runtime helpers.
- **Audience:** Makers who want a single command to bootstrap AI apps and a single menu/web UI to keep them updated.

## Quick start (5 minutes)
1. Clone the repo on a supported Linux distro (or WSL2/Ubuntu on Windows).
2. From the repo root:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```
3. The installer defaults to the **Web Launcher** (the single UX surface). It records logs to `~/.config/aihub/logs/install-YYYYMMDD.log` and creates OS-appropriate shortcuts.
4. Launch again anytime with `./launcher/linux/start_web_launcher.sh` (Linux/WSL) or `launcher/windows/start_web_launcher.ps1` (Windows). Legacy `./launcher/linux/aihub_menu.sh` now redirects to the Web Launcher at `http://127.0.0.1:3939`.

### Windows 10 quick start
1. Install and open **Git Bash** (or use **WSL2 with Ubuntu**) so the repo can be cloned and bash-compatible paths resolve correctly.
2. Ensure a Windows package manager is available (`winget` or Chocolatey) for dependency installs triggered by the launcher wrappers.
3. From a **PowerShell** terminal in the repo root, run either the batch or PowerShell installer:
   ```powershell
   .\install.bat
   # or
   .\install.ps1
   ```
4. The installer logs to `%APPDATA%\AIHub\logs\install-YYYYMMDD.log`, and shortcuts are created under the Start Menu and Desktop (matching `.lnk`, `.bat`, and `.ps1` wrappers called by the launchers).
5. Re-launch anytime via `launcher\windows\start_web_launcher.ps1` (web UI at `http://127.0.0.1:3939`) or the dedicated action wrappers like `launcher\windows\install_webui.ps1` and `launcher\windows\run_webui.ps1`. Linux instructions above remain unchanged for WSL.

> **Need a hands-free run?** `./install.sh --headless --install webui --gpu nvidia` mirrors the guided flow without dialogs. Add `--config <file>` to feed a JSON/env config (see [`docs/headless_config.md`](docs/headless_config.md)).

## Project architecture
AI-Hub keeps system-facing logic in bash and workflow logic in Python. The major building blocks are:

### Shell modules (`modules/shell`)
System detection, installers, and launch helpers. Key scripts include:
- `install/` – distro-aware bootstrap, dependency checks, GPU detection, and shortcut creation.
- `launch/` – start/stop helpers for Stable Diffusion WebUI, KoboldAI, SillyTavern, ComfyUI, and supporting services.
- `filters/` – model/LoRA filtering and manifest utilities.
- `helpers/` – logging, retries, download wrappers, and configuration readers used by the menu and web launcher.

All new/updated scripts enforce `set -euo pipefail`, quote variables, and are safe to re-run.

### Python runtime modules (`modules/runtime`)
Schema-first runtimes that expose structured JSON workflows used by the web launcher and CLI:
- `prompt_builder/` – Scene-driven prompt compiler with deterministic/heuristic prompt assembly, LoRA call lists, and `apply_feedback_to_scene` directives for iterative refinements.
- `character_studio/` – Character card management, dataset prep, captioning/tagging helpers, and `apply_feedback_to_character` for deterministic key/value updates.
- `web_launcher/` – HTTP server routes that surface installs, manifests, prompt compilation, and character registry reads to the browser UI. Configurable via `AIHUB_WEB_HOST`, `AIHUB_WEB_PORT`, and `AIHUB_WEB_TOKEN`/`--auth-token`.
- `hardware/` – GPU/CPU probes surfaced to launchers and logs.
- `audio/` and `video/` – multimedia helpers kept separate from install logic.
- `registry.py` & `models/` – typed dataclasses and helpers shared across runtimes.

### Shared utilities
- `modules/bootstrap/` – workspace prep and common environment checks reused by installers.
- `modules/config_service/` – config parsing and persistence for headless runs and launchers.
- `manifests/` – JSON metadata for models and LoRAs (hash, size, tags, mirrors, suggested frontends).
- `launcher/` – Cross-platform entrypoints: bash, PowerShell, batch, and Python thin wrappers for menus and GPU hints.
- `docs/` – Quickstarts, performance flags, roadmap, and launcher notes.

## Visual workflows
```
[install.sh or install.ps1]
    │
    ├─► Shell bootstrap (GPU + deps)
    │      ├─ validates packages
    │      ├─ detects NVIDIA/AMD/Intel/CPU
    │      └─ creates shortcuts + logs
    │
    └─► Launcher choice
           └─ Web Launcher (launcher/linux/start_web_launcher.sh)
                 └─ HTTP routes → Python runtimes → manifests/config
```

```
[Web Launcher / Menu action]
    │
    ├─ Install target (webui/kobold/sillytavern/loras/models)
    │     └─ shell installers + manifests + workspace prep
    │
    ├─ Run target
    │     └─ shell launchers (respecting GPU flags, low VRAM, DirectML)
    │
    ├─ Prompt Builder
    │     └─ POST scene JSON → prompt_builder compiler → structured prompt output
    │
    └─ Character Studio
          └─ card/dataset/tagging helpers → JSON responses and logs
```

## Usage guide
### Web launcher
- Start with `./launcher/linux/start_web_launcher.sh` (Linux/WSL) or the matching PowerShell/Batch/macOS wrappers in `launcher/windows` and `launcher/linux`.
- Defaults to `http://127.0.0.1:3939`; override host/port with `AIHUB_WEB_HOST`/`AIHUB_WEB_PORT`.
- Protect APIs with `AIHUB_WEB_TOKEN` or `--auth-token`.
- The Web Launcher UI already includes Guided Scene Builder + Quick Prompt for Prompt Builder and a Character Studio page for cards, datasets, and tag helpers.
- Surfaced routes include install triggers, manifest browsing, prompt compilation (with history saved to `~/.cache/aihub/prompt_builder/prompt_history.json`), character registry reads, and job logs. Prompt bundles are written to `~/.cache/aihub/prompt_builder/prompt_bundle.json` unless `PROMPT_BUNDLE_PATH` is set.

### Legacy YAD menu (deprecated)
- `./launcher/linux/aihub_menu.sh` now redirects to the Web Launcher to keep Linux UX aligned with other platforms.

### Command-line shortcuts
- Headless install: `./install.sh --headless --gpu <nvidia|amd|intel|cpu> --install <webui|kobold|sillytavern|loras|models>`
- Use `--config <file>` for repeatable unattended runs (JSON or env-style). See [`docs/headless_config.md`](docs/headless_config.md).
- After install, re-run launchers directly (e.g., `./modules/shell/run_webui.sh`, `./modules/shell/run_kobold.sh`) or use menu buttons. On Windows, the matching `.ps1`/`.bat` wrappers are available (for example, `launcher\windows\install_webui.ps1`, `launcher\windows\run_kobold.bat`, `launcher\windows\health_summary.ps1`).

## Advanced options and setup
- **Performance flags:** FP16 defaults on NVIDIA; xFormers is offered for NVIDIA; DirectML toggles apply on Windows/WSL for AMD/Intel; low-VRAM mode adds `--medvram` for WebUI. Details in [`docs/performance_flags.md`](docs/performance_flags.md).
- **GPU guidance:** Detected GPUs are logged and surfaced during install; AMD notes point to ROCm; Intel notes point to oneAPI/OpenVINO; CPU mode remains available.
- **Shortcuts:** Linux `.desktop`, Windows `.lnk`/`.bat`/`.ps1`, macOS `.command`/app bundle. Locations and cleanup steps in [`docs/shortcuts.md`](docs/shortcuts.md).
- **Logs:** All installers and launchers write to `~/.config/aihub/logs/install-YYYYMMDD.log` (or `%APPDATA%\AIHub\logs\install-YYYYMMDD.log` on Windows). Menu/web flows reuse the same log for troubleshooting.
- **Environment variables:**
  - `AIHUB_WEB_HOST`/`AIHUB_WEB_PORT` – bind address/port for web launcher.
  - `AIHUB_WEB_TOKEN` – bearer token required by web APIs.
  - `AIHUB_PYTHON` – override Python interpreter for Windows wrappers.
  - `AIHUB_LOG_PATH` – custom log destination when needed.
  - `AIHUB_LOG_DIR` – custom log directory for wrapper/log helpers.

## Models and LoRAs
- Base models live in `$HOME/ai-hub/models/`; SD v1.5 is fetched by default. LoRAs and curated presets land in `~/AI/LoRAs`.
- Manifests list hashes, sizes, mirrors, tags, and frontend hints to keep downloads predictable.
- The [Model and LoRA quickstart](docs/quickstart_models.md) covers SD1.5/SDXL presets, download locations, and pairing flows across WebUI, KoboldAI, and SillyTavern.

## Troubleshooting
- Missing packages? Re-run `./install.sh` (it will prompt before installing and retries gracefully if you cancel).
- Slow downloads? Provide a Hugging Face token when prompted so `aria2c`/`wget` can use authenticated mirrors.
- No GPU detected? Continue with CPU mode; expect slower inference.
- Desktop icon missing? Verify `${XDG_DATA_HOME:-$HOME/.local/share}/applications/ai-hub-launcher.desktop` exists and your DE trusts local `.desktop` files on `~/Desktop`.
- Permission issues? Ensure your user can run `sudo` for package installs.

## Contributing
Contributions are welcome! Keep bash helpers small and idempotent, avoid wrapping imports in `try/except`, and mirror Python style (type hints + `pathlib`). Open a PR with focused changes and matching docs/tests where relevant.

## License
This project is licensed under the terms of the [LICENSE](LICENSE) file.
