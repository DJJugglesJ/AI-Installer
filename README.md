# AI Installer

AI Installer sets up a modular AI workstation on Ubuntu 22.04 (including Windows via WSL2 + Ubuntu). It presents AI-Hub as a general-purpose orchestration layer for image and text workflows (e.g., Stable Diffusion, KoboldAI, SillyTavern), model/LoRA management, and pairing routines, while handling GPU detection and prerequisite checks for you. Examples are written in a neutral style so they can be reused across setups, and AI-Hub can optionally support adult content workflows depending on your configuration and local policies.

See the [roadmap](docs/ROADMAP.md) for current capabilities, milestones, and the feature wishlist.

## Prerequisites
- **Operating system:** Ubuntu 22.04.
- **Packages:** The installer will prompt to install missing dependencies. It expects `git`, `curl`, `jq`, `yad`, `python3`, `python3-pip`, `wget`, `aria2`, and a terminal emulator (`gnome-terminal`, `x-terminal-emulator`, `konsole`, or `kitty`).
- **Permissions:** Ability to run `sudo apt update` and `sudo apt install` when prompted.

## Installation
1. Clone or download this repository on Ubuntu 22.04. On Windows, enable WSL2 and install the Ubuntu distribution first, then launch the installer from the WSL shell.
2. From the repo root, run:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```
   *Use `./install.sh --headless --gpu cpu --install webui` to run without any YAD prompts while forcing CPU mode and directly installing the Stable Diffusion WebUI. Use `./install.sh --help` to view all flags.*
3. The installer will:
   - Ensure required packages are available (prompting to install missing ones).
   - Detect your GPU and suggest a driver (NVIDIA) or continue with CPU/Intel/AMD fallbacks.
   - Create a desktop entry pointing to `aihub_menu.sh` so you can launch the menu from your Desktop.

## Command-line options
- `--headless`: Run without YAD dialogs, using config defaults and logging headless decisions to `~/.config/aihub/install.log`.
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
- **AMD:** The installer can install `mesa-vulkan-drivers` for the open-source stack and will record the detected AMD GPU. For
  hardware acceleration beyond the default Vulkan/OpenCL stack, plan to configure ROCm following the [AMD ROCm installation
  guide](https://rocm.docs.amd.com/en/latest/deploy/linux/install.html). Expect workloads to fall back to CPU if ROCm/AMDGPU
  acceleration is unavailable.
- **Intel:** Intel GPUs are detected, but the installer defaults to CPU mode for AI workloads. To enable Intel acceleration,
  configure oneAPI/OpenVINO as described in Intel's [OpenVINO toolkit overview](https://www.intel.com/content/www/us/en/developer/tools/openvino-toolkit/overview.html). Until that is configured, assume CPU-only performance.
- If no supported GPU is found, the installer can continue in CPU mode (slower inference).

## Windows / WSL2 notes
- AI-Hub is designed to run inside a Linux environment. On Windows, enable WSL2, install Ubuntu 22.04, and run the installer from that WSL shell.
- The installer expects to manage Linux packages and create launchers inside the WSL distribution; Windows-native paths or shells are not supported.

## Models and LoRAs
- Base models download to `$HOME/ai-hub/models/`. The Stable Diffusion v1.5 checkpoint is fetched by default.
- Hugging Face tokens are optional but recommended for gated or rate-limited downloads; tokens are stored in `~/.config/aihub/installer.conf`.
- LoRA utilities can install/update assets and pair them with supported frontends.

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
