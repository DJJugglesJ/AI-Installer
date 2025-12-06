# AI Installer

AI-Hub provides a unified installer and launcher for creative and conversational AI tools on Linux (including Windows via WSL2). The goal is to give newcomers a dependable, repeatable setup that handles GPUs, dependencies, and launch workflows so you can focus on using the apps rather than wiring them together. See the [roadmap](docs/ROADMAP.md) for current capabilities and upcoming milestones.

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
- **Launcher capabilities:**
  - Launch apps, update assets, manage pairings, and self-update the installer via `aihub_menu.sh` or the desktop shortcut it creates.
  - Direct install targets with `--install <target>` for `webui`, `kobold`, `sillytavern`, `loras`, or `models` when you want to skip the menu.

## Prerequisites
- **Operating system:** Tested on Ubuntu/Debian, Arch, and Fedora/RHEL-based distributions (including WSL2 with Ubuntu). Other distributions may work with manual dependency installation.
- **Packages:** `git`, `curl`, `jq`, `yad`, `python3` (or `python` on Arch), `python3-pip`/`python-pip`, `nodejs`, `npm`, `wget`, `aria2`, and GPU helpers (`ubuntu-drivers-common`/`mesa-utils` or `vulkan-tools`/`mesa-dri-drivers` on RPM-based systems). Missing tools are installed for you during bootstrap.
- **Permissions:** Ability to run package manager commands with `sudo` when prompted.

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
   - Detect your GPU and suggest a driver (NVIDIA) or continue with CPU/Intel/AMD fallbacks.
   - Create a desktop entry pointing to `aihub_menu.sh` so you can launch the menu from your Desktop.

## Command-line options
- `--headless`: Run without YAD dialogs, using config defaults and logging headless decisions to `~/.config/aihub/install.log`.
- `--config <file>`: Provide a JSON or env-style config file for headless runs (see [`docs/headless_config.md`](docs/headless_config.md)).
- `--gpu <mode>`: Force a GPU mode (`nvidia`, `amd`, `intel`, or `cpu`) and skip the GPU prompt.
- `--install <target>`: Trigger a direct install for `webui`, `kobold`, `sillytavern`, `loras`, or `models` immediately after setup.

## Launcher menu
Running `aihub_menu.sh` (or the desktop shortcut) opens a YAD-based menu with these actions:
- **🖼️ Run Stable Diffusion WebUI:** Start the Stable Diffusion WebUI environment.
- **🤖 Launch KoboldAI:** Start KoboldAI.
- **🧠 Launch SillyTavern:** Start SillyTavern.
- **📥 Install or Update LoRAs:** Fetch or refresh LoRA assets.
- **📦 Install or Update Models:** Download base models (e.g., SD1.5) with optional Hugging Face tokens for gated content.
- **🆕 Update Installer:** Run the self-update workflow (pulls latest code and relaunches the menu).
- **🔁 Pull Updates:** Simple `git pull` to refresh the repository when it was cloned from GitHub.
- **🧠/🎭 Pair LLM + LoRA:** Pair models and LoRAs for oobabooga or SillyTavern flows.
- **🎨 Select LoRA for Preset / 💾 Save Current Pairing / 📂 Load Saved Pairing:** Manage pairing presets.
- **❌ Exit:** Close the menu.

## GPU considerations
- NVIDIA cards trigger an optional driver install via `ubuntu-drivers autoinstall`.
- **AMD:** The installer can install `mesa-vulkan-drivers` for the open-source stack and will record the detected AMD GPU. For hardware acceleration beyond the default Vulkan/OpenCL stack, plan to configure ROCm following the [AMD ROCm installation guide](https://rocm.docs.amd.com/en/latest/deploy/linux/install.html). Expect workloads to fall back to CPU if ROCm/AMDGPU acceleration is unavailable.
- **Intel:** Intel GPUs are detected, but the installer defaults to CPU mode for AI workloads. To enable Intel acceleration, configure oneAPI/OpenVINO as described in Intel's [OpenVINO toolkit overview](https://www.intel.com/content/www/us/en/developer/tools/openvino-toolkit/overview.html). Until that is configured, assume CPU-only performance.
- If no supported GPU is found, the installer can continue in CPU mode (slower inference).
- **Performance flags:**
  - FP16 defaults to **enabled on NVIDIA** and **disabled elsewhere**; the installer will force full precision when FP16 is unstable/unsupported.
  - xFormers is exposed for NVIDIA GPUs with working drivers. DirectML is offered for AMD/Intel GPUs under Windows/WSL and disables xFormers when enabled.
  - Low VRAM mode adds `--medvram` for WebUI. It is recommended automatically when <8GB VRAM is detected (NVIDIA) and can be toggled in the launcher or headless config.
  - See [`docs/performance_flags.md`](docs/performance_flags.md) for defaults and trade-offs by GPU family.

## Windows / WSL2 notes
- AI-Hub is designed to run inside a Linux environment. On Windows, enable WSL2, install Ubuntu 22.04, and run the installer from that WSL shell.
- The installer expects to manage Linux packages and create launchers inside the WSL distribution; Windows-native paths or shells are not supported.

## Models and LoRAs
- Base models download to `$HOME/ai-hub/models/`. The Stable Diffusion v1.5 checkpoint is fetched by default.
- Hugging Face tokens are optional but recommended for gated or rate-limited downloads; tokens are stored in `~/.config/aihub/installer.conf`.
- LoRA utilities can install/update assets and pair them with supported frontends.
- See the [model and LoRA quickstart](docs/quickstart_models.md) for a concise guide to installing SD1.5, knowing where assets live, and pairing LoRAs across WebUI, KoboldAI, and SillyTavern.

## Updates and self-update
- Use **🆕 Update Installer** from the menu for a guided self-update (requires the repo to have a `.git` directory).
- Use **🔁 Pull Updates** for a quick `git pull` when you already cloned from GitHub.

## Troubleshooting / FAQ
- **Missing packages:** The installer will prompt to install them. Re-run `./install.sh` if a run was canceled.
- **Desktop icon not appearing:** Ensure the desktop entry was created at `~/Desktop/AI-Workstation-Launcher.desktop` and that your desktop environment allows launching local desktop files.
- **Slow downloads or failures:** Provide a Hugging Face token when prompted and ensure `aria2c` or `wget` can reach the internet.
- **No GPU detected:** Continue with CPU mode; expect slower performance.
- **Permission errors:** Make sure your user can run `sudo` commands.

## Contributing
Contributions are welcome! Fork the repository, make changes on a branch, and open a pull request. Please keep scripts modular and avoid wrapping imports in try/catch blocks (per project style).

## License
This project is licensed under the terms of the [LICENSE](LICENSE) file.
