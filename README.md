# AI Installer

AI-Hub provides a unified installer and launcher for creative and conversational AI tools on Linux (including Windows via WSL2). The goal is to give newcomers a dependable, repeatable setup that handles GPUs, dependencies, and launch workflows so you can focus on using the apps rather than wiring them together.

### How it is structured today
- **Shell-first helpers:** Easy-to-read bash utilities live in [`modules/shell`](modules/shell) and power both the YAD menu and the web launcher endpoints.
- **Runtime bundles:** Prepared runtimes, schemas, and JS/JSON helpers live in [`modules/runtime`](modules/runtime) (e.g., `modules/runtime/prompt_builder` and `modules/runtime/character_studio`) so you can review what gets shipped without digging through logs.
- **Expanded manifests:** Model and LoRA manifests track hashes, sizes, tags, mirrors, and frontend hints to keep downloads reliable and parity between shell and web launchers.
- **Safer installer prompts:** Interactive runs clarify GPU suggestions, call out AMD/Intel guidance, and retry canceled package installs without forcing you to start over.
- **Stability-first defaults:** Installer entrypoints run with strict bash safety flags, validate prerequisites before proceeding, and record errors to `~/.config/aihub/install.log`. Runtime services validate manifest JSON and prompt-builder payloads before exposing them to clients, and helper modules log failures instead of silently ignoring them.

See the [roadmap](docs/ROADMAP.md) for present capabilities, platform targets, and upcoming milestones.

## Why it matters
- **Reliable setup:** Cross-distro bootstrapper installs prerequisites, validates GPU drivers, and records configuration so you avoid guesswork.
- **One menu for many tools:** Launch or update Stable Diffusion WebUI, KoboldAI, SillyTavern, model downloads, and LoRA utilities from a single place.
- **Guided performance:** Sensible defaults for FP16, xFormers, low-VRAM mode, and GPU fallbacks keep things running smoothly across hardware.
- **Designed for shared devices:** Headless automation and desktop shortcuts make it easy to support multiple users or repeat installations.

## New to AI-Hub? Start here
- **Supported workflows:**
  - Image generation with Stable Diffusion WebUI
  - Text and story workflows with KoboldAI
  - Chat/front-end experiences with SillyTavern
  - Model and LoRA download, pairing, and preset management
- **Installation modes:**
  - **Interactive:** `./install.sh` with guided YAD dialogs for GPU selection, package installation, and feature toggles.
  - **Headless/automated:** `./install.sh --headless` with optional config file (`--config <file>`) for unattended deployments. See [`docs/headless_config.md`](docs/headless_config.md).
  - Both options lean on the same small shell helpers in [`modules/shell`](modules/shell) and the prepared runtime bundles in [`modules/runtime`](modules/runtime), so the steps stay predictable whether you click through or run headless.
- **Quickstarts:**
  - For a concise Stable Diffusion and LoRA setup (including a new SDXL/SD1.5 preset rundown), see the refreshed [Model and LoRA quickstart](docs/quickstart_models.md).
  - Coming from WSL or a lightweight desktop? The quickstart highlights the updated prompts that surface GPU guidance and download mirrors so you can complete installs without guessing.
- **Launcher capabilities:**
  - Launch apps, update assets, manage pairings, and self-update the installer via `aihub_menu.sh` or the desktop shortcut it creates.
  - Direct install targets with `--install <target>` for `webui`, `kobold`, `sillytavern`, `loras`, or `models` when you want to skip the menu.
  - Curious how it works? The menu buttons simply call the same friendly shell helpers in [`modules/shell`](modules/shell) and rely on the bundled runtimes kept in [`modules/runtime`](modules/runtime), so nothing is hidden behind complex tools.

## Prerequisites
- **Operating system:** Tested on Ubuntu/Debian, Arch, and Fedora/RHEL-based distributions (including WSL2 with Ubuntu). Other distributions may work with manual dependency installation.
- **Packages:** `git`, `curl`, `jq`, `yad`, `python3` (or `python` on Arch), `python3-pip`/`python-pip`, `nodejs`, `npm`, `wget`, `aria2`, and GPU helpers (`ubuntu-drivers-common`/`mesa-utils` or `vulkan-tools`/`mesa-dri-drivers` on RPM-based systems). Missing tools are installed for you during bootstrap.
- **Python packages:** Install `PyYAML` before running the installer so YAML profiles/configs can be parsed: `pip install -r requirements.txt` (or `pip install PyYAML`).
- **Permissions:** Ability to run package manager commands with `sudo` when prompted.

### What you get out of the box
- **Defensive install/launch flows:** Shell entrypoints enforce `set -euo pipefail`, validate required commands, and bail out with actionable logs when dependencies or permissions are missing.
- **Schema-aware runtimes:** Prompt Builder and Character Studio ship typed dataclasses with lightweight validation so malformed scenes, characters, or LoRA bundles are rejected early.
- **Manifest safety:** The web launcher parses `manifests/*.json` defensively, returning structured `errors` when files are malformed instead of crashing or serving incomplete lists.
- **History and log hygiene:** Install history, manifest loads, and job monitoring emit clear timestamps and capture failures in `~/.config/aihub/install.log` for easier support.

## Installation
1. Clone or download this repository on a supported distro. On Windows, enable WSL2 and install the Ubuntu distribution first, then launch the installer from the WSL shell.
2. From the repo root, run:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```
   *Use `./install.sh --headless --gpu cpu --install webui` to run without prompts while forcing CPU mode and directly installing the Stable Diffusion WebUI. Use `./install.sh --help` to view all flags.*
3. The installer will:
   - Run a cross-distro bootstrap to install or verify required packages (skipping tools that are already present and logging versions). On unsupported distributions, install dependencies manually with your package manager.
   - Ask before installing missing packages and retry gracefully if you cancel partway through.
   - Detect your GPU and suggest a driver (NVIDIA) or continue with CPU/Intel/AMD fallbacks while surfacing ROCm/oneAPI/DirectML guidance when relevant.
   - Create OS-appropriate shortcuts for `aihub_menu.sh` (Linux `.desktop`, Windows `.lnk`/`.bat`/`.ps1`, or macOS `.app`/`.command`) and record their paths in `~/.config/aihub/install.log`.

## Command-line options
- `--headless`: Run without YAD dialogs, using config defaults and logging headless decisions to `~/.config/aihub/install.log`.
- `--config <file>`: Provide a JSON or env-style config file for headless runs (see [`docs/headless_config.md`](docs/headless_config.md)).
- `--gpu <mode>`: Force a GPU mode (`nvidia`, `amd`, `intel`, or `cpu`) and skip the GPU prompt.
- `--install <target>`: Trigger a direct install for `webui`, `kobold`, `sillytavern`, `loras`, or `models` immediately after setup.

## Launcher menu and web UI
You now have two ways to drive installs/launches:
- **Web launcher (recommended):** `./launcher/start_web_launcher.sh` (or the Windows PowerShell/Batch/macOS `.command` equivalents) starts a lightweight local server at `http://127.0.0.1:3939` that serves a bundled HTML/JS UI. Buttons call the same shell helpers as the legacy menu while also exposing prompt compilation, manifest browsing, and Character Studio registry reads over JSON APIs. Set `AIHUB_WEB_HOST`/`AIHUB_WEB_PORT` to change the bind or `AIHUB_WEB_TOKEN`/`--auth-token` to require a bearer token for the APIs. See [docs/web_launcher.md](docs/web_launcher.md) for hosting, authentication, and OS-specific notes.
- **Legacy YAD menu:** `./aihub_menu.sh` (or the existing desktop shortcut) remains available for environments that prefer the dialog-based workflow with clearer action labels, hover help, and defaults that match the web launcher.

Running `aihub_menu.sh` (or the desktop shortcut) opens a YAD-based menu with these actions:
- **🖼️ Run Stable Diffusion WebUI:** Launch from `~/AI/WebUI` using the existing Stable-diffusion/ model folder and GPU flags.
- **🤖 Launch KoboldAI:** Start KoboldAI from `~/AI/KoboldAI` with your downloaded models.
- **🧠 Launch SillyTavern:** Start SillyTavern in `~/AI/SillyTavern` against your chosen backend.
- **📥 Install or Update LoRAs:** Install or refresh LoRA assets into `~/AI/LoRAs` (curated + CivitAI) with clearer retry prompts.
- **📦 Install or Update Models:** Download or update base/LLM models into `~/ai-hub/models` (Hugging Face tokens stay optional) with resumable downloads and mirror fallbacks.
- **🆕 Update Installer:** Self-update bundled installer scripts and relaunch the menu.
- **🔁 Pull Updates:** Run a quick `git pull` when you cloned the repository manually.
- **🧠/🎭 Pair LLM + LoRA:** Pair models and LoRAs for oobabooga or SillyTavern flows with defaults that match the menu/web launcher.
- **🎨 Select LoRA for Preset / 💾 Save Current Pairing / 📂 Load Saved Pairing:** Manage pairing presets.
- **❌ Exit:** Close the menu.

### Shortcut locations
- **Linux:** The primary `.desktop` entry lives at `${XDG_DATA_HOME:-$HOME/.local/share}/applications/ai-hub-launcher.desktop` with a convenience copy on the Desktop when available.
- **Windows / WSL:** Desktop helpers (`AI-Hub-Launcher.bat`/`AI-Hub-Launcher.ps1`) and `.lnk` shortcuts land on the Desktop and Start Menu (`%PROGRAMS%`). Native runs point `.lnk` files directly at PowerShell while WSL-aware wrappers stay available for WSL-first installs.
- **macOS:** `~/Desktop/AI-Hub-Launcher.command` plus a user-level app bundle at `~/Applications/AI Hub Launcher.app` that wraps the selected launcher target.
See [`docs/shortcuts.md`](docs/shortcuts.md) for cleanup/uninstall steps and environment detection details. Shortcut creation attempts and the detected desktop environment are logged to `~/.config/aihub/install.log` for troubleshooting.

## GPU considerations
- NVIDIA cards trigger an optional driver install via `ubuntu-drivers autoinstall`.
- **AMD:** The installer can install `mesa-vulkan-drivers` for the open-source stack and will record the detected AMD GPU. For hardware acceleration beyond the default Vulkan/OpenCL stack, plan to configure ROCm following the [AMD ROCm installation guide](https://rocm.docs.amd.com/en/latest/deploy/linux/install.html). Validate support with `rocminfo`/`clinfo` before enabling ROCm/HIP toggles; the GPU detection logs and launcher output call this guidance out when an AMD adapter is present (DirectML is exposed when running under Windows/WSL) and the installer now surfaces these pointers inline during GPU selection.
- **Intel:** Intel GPUs are detected, but the installer defaults to CPU mode for AI workloads. To enable Intel acceleration, configure oneAPI/OpenVINO as described in Intel's [OpenVINO toolkit overview](https://www.intel.com/content/www/us/en/developer/tools/openvino-toolkit/overview.html). Installing `intel-opencl-icd` or the Level Zero/oneAPI runtimes and enabling OpenVINO/DirectML toggles is recommended; the detection scripts surface this hint and record the driver stack in the log, and the dialogs now spell out the default CPU-safe path when acceleration is unavailable.
- If no supported GPU is found, the installer can continue in CPU mode (slower inference).
- **Performance flags:**
  - FP16 defaults to **enabled on NVIDIA** and **disabled elsewhere**; the installer will force full precision when FP16 is unstable/unsupported.
  - xFormers is exposed for NVIDIA GPUs with working drivers. DirectML is offered for AMD/Intel GPUs under Windows/WSL and disables xFormers when enabled.
  - Low VRAM mode adds `--medvram` for WebUI. It is recommended automatically when <8GB VRAM is detected (NVIDIA) and can be toggled in the launcher or headless config.
  - See [`docs/performance_flags.md`](docs/performance_flags.md) for defaults and trade-offs by GPU family.

## Windows / WSL2 notes
- AI-Hub is designed to run inside a Linux environment. On Windows, enable WSL2, install Ubuntu 22.04, and run the installer from that WSL shell when you want the bash-first experience. A native PowerShell installer (`install.ps1`) now mirrors the core flags, provisions workspaces, validates tooling with `winget`/`choco`, writes logs to `%LOCALAPPDATA%\AIHub\logs`, and creates Desktop/Start Menu shortcuts without requiring WSL.
- WSL-aware launchers remain available for ROCm/WSL-first workflows, but `.lnk` files now target PowerShell directly when running on Windows so shortcut creation no longer depends on `wsl.exe`.
- **Windows entry points:** `launcher/aihub_menu.bat` and `launcher/aihub_menu.ps1` call the Python helper `launcher/aihub_menu.py`, which mirrors `aihub_menu.sh` actions, performs lightweight GPU detection (including DirectML hints), and logs to `%LOCALAPPDATA%\AIHub\logs\install.log` on Windows (or `~/.config/aihub/install.log` under WSL). Use these when creating `.lnk` shortcuts on Windows.
- **GPU probes:** `launcher/detect_gpu.ps1` and `launcher/detect_gpu.bat` emit the same detection summary as the Linux launcher while guiding Windows users toward WSL2 when shell-based actions are required.
- **Running inside WSL:** Launch `aihub_menu.sh` directly or run `python launcher/aihub_menu.py --list-actions` for a headless-friendly menu. Actions that depend on the shell helpers still require a WSL bash environment; the Windows `.bat`/`.ps1` wrappers will emit a log message if bash is unavailable.
- **Native Windows vs WSL2:** The Windows wrappers search for Python via `AIHUB_PYTHON`, a repo `.venv`, or system installs and then set `AIHUB_LOG_PATH` to a Windows-friendly location. When invoked on native Windows for shell-first actions, they remind you to pivot into WSL2; inside WSL2 the same scripts reuse the Linux bash helpers transparently.

## Models and LoRAs
- Base models download to `$HOME/ai-hub/models/`. The Stable Diffusion v1.5 checkpoint is fetched by default.
- Hugging Face tokens are optional but recommended for gated or rate-limited downloads; tokens are stored in `~/.config/aihub/installer.conf`.
- LoRA utilities can install/update assets and pair them with supported frontends.
- See the [model and LoRA quickstart](docs/quickstart_models.md) for a concise guide to installing SD1.5, knowing where assets live, and pairing LoRAs across WebUI, KoboldAI, and SillyTavern.

## Updates and self-update
- Use **🆕 Update Installer** from the menu for a guided self-update that refreshes bundled scripts and relaunches the menu (expects a `.git` checkout).
- Use **🔁 Pull Updates** for a quick `git pull` when you already cloned from GitHub and want to keep local tweaks intact.

## Troubleshooting / FAQ
- **Missing packages:** The installer will prompt to install them. Re-run `./install.sh` if a run was canceled.
  - **Desktop icon not appearing:** Ensure the `.desktop` entry exists under `${XDG_DATA_HOME:-$HOME/.local/share}/applications` and that your desktop environment allows launching local desktop files placed on `~/Desktop`.
- **Slow downloads or failures:** Provide a Hugging Face token when prompted and ensure `aria2c` or `wget` can reach the internet.
- **No GPU detected:** Continue with CPU mode; expect slower performance.
- **Permission errors:** Make sure your user can run `sudo` commands.
- **Package retries and logs:** If a package command fails or you cancel it, the installer will ask whether to retry and record each attempt in `~/.config/aihub/install.log`. Check that log before re-running in headless mode so you know which step failed.

## Contributing
Contributions are welcome! Fork the repository, make changes on a branch, and open a pull request. Please keep scripts modular and avoid wrapping imports in try/catch blocks (per project style).

## License
This project is licensed under the terms of the [LICENSE](LICENSE) file.
