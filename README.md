# AI Installer

AI Installer sets up a modular AI workstation on Ubuntu 22.04. It creates a desktop launcher with quick actions for common AI tools (Stable Diffusion, KoboldAI, SillyTavern), model/LoRA management, and pairing workflows, while handling GPU detection and prerequisite checks for you.

See the [roadmap](docs/ROADMAP.md) for current capabilities, milestones, and the feature wishlist.

## Prerequisites
- **Operating system:** Ubuntu 22.04.
- **Packages:** The installer will prompt to install missing dependencies. It expects `git`, `curl`, `jq`, `yad`, `python3`, `python3-pip`, `wget`, `aria2`, and a terminal emulator (`gnome-terminal`, `x-terminal-emulator`, `konsole`, or `kitty`).
- **Permissions:** Ability to run `sudo apt update` and `sudo apt install` when prompted.

## Installation
1. Clone or download this repository on Ubuntu 22.04.
2. From the repo root, run:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```
3. The installer will:
   - Ensure required packages are available (prompting to install missing ones).
   - Detect your GPU and suggest a driver (NVIDIA) or continue with CPU/Intel/AMD fallbacks.
   - Create a desktop entry pointing to `aihub_menu.sh` so you can launch the menu from your Desktop.

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
- AMD and Intel GPUs fall back to CPU unless you configure vendor-specific acceleration separately.
- If no supported GPU is found, the installer can continue in CPU mode (slower inference).

## Models and LoRAs
- Base models download to `~/AI/models/`. The Stable Diffusion v1.5 checkpoint is fetched by default.
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
