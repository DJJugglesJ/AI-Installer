# AI-Hub

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
3. Pick **Web Launcher** or **YAD Menu** when prompted. The installer records logs to `~/.config/aihub/install.log` and creates OS-appropriate shortcuts.
4. Launch again anytime with `./aihub_menu.sh` (Linux/WSL) or `launcher/aihub_menu.ps1` (Windows). Use `./launcher/start_web_launcher.sh` for the browser UI at `http://127.0.0.1:3939`.

### Windows 10 quick start
1. Install and open **Git Bash** (or use **WSL2 with Ubuntu**) so the repo can be cloned and bash-compatible paths resolve correctly.
2. Ensure a Windows package manager is available (`winget` or Chocolatey) for dependency installs triggered by the launcher wrappers.
3. From a **PowerShell** terminal in the repo root, run either the batch or PowerShell installer:
   ```powershell
   .\install.bat
   # or
   .\install.ps1
   ```
4. The installer logs to `%LOCALAPPDATA%\AIHub\logs\install.log`, and shortcuts are created under the Start Menu and Desktop (matching `.lnk`, `.bat`, and `.ps1` wrappers called by the launchers).
5. Re-launch anytime via `launcher\aihub_menu.ps1` (menu) or `launcher\start_web_launcher.ps1` (web UI at `http://127.0.0.1:3939`). Linux instructions above remain unchanged for WSL.

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
- `prompt_builder/` – Scene-driven prompt compiler with LLM-backed positive/negative prompts, LoRA call lists, and `apply_feedback_to_scene` for iterative refinements.
- `character_studio/` – Character card management, dataset prep, captioning/tagging helpers, and `apply_feedback_to_character` for LLM-guided edits.
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
           ├─ YAD Menu (aihub_menu.sh)
           │     └─ calls shell helpers per action
           └─ Web Launcher (start_web_launcher.sh)
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
### Launcher menu (YAD)
- Run `./aihub_menu.sh` to open the dialog-based menu.
- Actions include launching WebUI/KoboldAI/SillyTavern, installing or updating models/LoRAs, pairing LoRAs with models, self-updating the installer, and pulling git updates.
- Menu buttons directly call the same shell helpers used by the headless and web flows.

### Web launcher
- Start with `./launcher/start_web_launcher.sh` (Linux/WSL) or the matching PowerShell/Batch/macOS wrappers.
- Defaults to `http://127.0.0.1:3939`; override host/port with `AIHUB_WEB_HOST`/`AIHUB_WEB_PORT`.
- Protect APIs with `AIHUB_WEB_TOKEN` or `--auth-token`.
- Surfaced routes include install triggers, manifest browsing, prompt compilation, character registry reads, and job logs.

### Command-line shortcuts
- Headless install: `./install.sh --headless --gpu <nvidia|amd|intel|cpu> --install <webui|kobold|sillytavern|loras|models>`
- Use `--config <file>` for repeatable unattended runs (JSON or env-style). See [`docs/headless_config.md`](docs/headless_config.md).
- After install, re-run launchers directly (e.g., `./launcher/start_webui.sh`, `./launcher/start_kobold.sh`) or use menu buttons.

## Advanced options and setup
- **Performance flags:** FP16 defaults on NVIDIA; xFormers is offered for NVIDIA; DirectML toggles apply on Windows/WSL for AMD/Intel; low-VRAM mode adds `--medvram` for WebUI. Details in [`docs/performance_flags.md`](docs/performance_flags.md).
- **GPU guidance:** Detected GPUs are logged and surfaced during install; AMD notes point to ROCm; Intel notes point to oneAPI/OpenVINO; CPU mode remains available.
- **Shortcuts:** Linux `.desktop`, Windows `.lnk`/`.bat`/`.ps1`, macOS `.command`/app bundle. Locations and cleanup steps in [`docs/shortcuts.md`](docs/shortcuts.md).
- **Logs:** All installers and launchers write to `~/.config/aihub/install.log` (or `%LOCALAPPDATA%\AIHub\logs` on Windows). Menu/web flows reuse the same log for troubleshooting.
- **Environment variables:**
  - `AIHUB_WEB_HOST`/`AIHUB_WEB_PORT` – bind address/port for web launcher.
  - `AIHUB_WEB_TOKEN` – bearer token required by web APIs.
  - `AIHUB_PYTHON` – override Python interpreter for Windows wrappers.
  - `AIHUB_LOG_PATH` – custom log destination when needed.

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
