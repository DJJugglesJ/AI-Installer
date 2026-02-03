# AI Hub launcher entrypoint inventory

This inventory captures launcher entrypoints and helper scripts, plus where they are referenced in the repo. The list is grouped by location to keep related scripts together.

## Root entrypoints

| Entrypoint | OS | Purpose | References |
| --- | --- | --- | --- |
| `install.sh` | Linux/macOS/WSL | Installer entrypoint (interactive/headless setup, config/logging). | `README.md`, `docs/quickstart_models.md`, `docs/config_service.md`, `tests/test_installer_config.py` |
| `install.ps1` | Windows | PowerShell installer (headless options, GPU/install target flags). | `README.md`, `install.bat`, `tools/windows.ps1` |
| `install.bat` | Windows | Batch wrapper that calls `install.ps1`. | `README.md`, `install.ps1` |
| `launcher/linux/aihub_menu.sh` | Linux/WSL | **Deprecated** YAD menu wrapper that now launches the Web Launcher. | `README.md`, `docs/shortcuts.md`, `docs/quickstart_models.md`, `install.sh`, `modules/shell/self_update.sh` |

## Launcher entrypoints (`launcher/`)

### Menu/web/status entrypoints

| Entrypoint | OS | Purpose | References |
| --- | --- | --- | --- |
| `launcher/linux/ai_hub_launcher.sh` | Linux/macOS/WSL | **Deprecated** status panel wrapper that now launches the Web Launcher. | `launcher/linux/aihub_menu.sh`, `launcher/common/aihub_menu.py`, `tools/windows.ps1` |
| `launcher/common/aihub_menu.py` | Windows/WSL | Headless-friendly action runner mirroring `launcher/linux/aihub_menu.sh`. | `launcher/windows/aihub_menu.ps1`, `launcher/windows/aihub_menu.bat`, `tests/test_windows_wrappers.py` |
| `launcher/windows/aihub_menu.ps1` | Windows | PowerShell entrypoint to run `aihub_menu.py`. | `README.md`, `docs/shortcuts.md`, `tools/windows.ps1`, `install.sh`, `install.ps1` |
| `launcher/windows/aihub_menu.bat` | Windows | Batch wrapper to run `aihub_menu.py`. | `install.sh` |
| `launcher/linux/start_web_launcher.sh` | Linux/macOS/WSL | Start web launcher server (`modules.runtime.web_launcher`). | `README.md`, `docs/web_launcher.md`, `docs/shortcuts.md`, `install.sh` |
| `launcher/windows/start_web_launcher.ps1` | Windows | PowerShell start for web launcher server. | `README.md`, `docs/web_launcher.md`, `docs/shortcuts.md`, `tools/windows.ps1`, `install.ps1` |
| `launcher/windows/start_web_launcher.bat` | Windows | Batch start for web launcher server. | `README.md`, `docs/web_launcher.md`, `install.sh` |
| `launcher/linux/start_web_launcher.command` | macOS | Double-clickable web launcher helper. | `docs/web_launcher.md` |

### Diagnostics entrypoints

| Entrypoint | OS | Purpose | References |
| --- | --- | --- | --- |
| `launcher/windows/detect_gpu.ps1` | Windows | Calls `aihub_menu.ps1 --detect-gpu`. | direct entrypoint |
| `launcher/windows/detect_gpu.bat` | Windows | Calls `aihub_menu.bat --detect-gpu`. | direct entrypoint |
| `launcher/windows/gpu_diagnostics.ps1` | Windows | Runs `modules.runtime.hardware.gpu_diagnostics`. | direct entrypoint |
| `launcher/windows/gpu_diagnostics.bat` | Windows | Runs `modules.runtime.hardware.gpu_diagnostics`. | direct entrypoint |

### Windows action entrypoints (`launcher/windows/*.ps1`/`launcher/windows/*.bat`)

PowerShell entrypoints use `launcher/windows/common.ps1` to invoke the shell helpers. Batch wrappers forward to `launcher/windows/aihub_menu.bat` with `--action <action>`.

| Entrypoint | OS | Purpose | References |
| --- | --- | --- | --- |
| `launcher/windows/install_webui.ps1` | Windows | Install/update Stable Diffusion WebUI. | `README.md`, `tests/test_windows_wrappers.py` |
| `launcher/windows/install_webui.bat` | Windows | Install/update Stable Diffusion WebUI. | `README.md`, `tests/test_windows_wrappers.py` |
| `launcher/windows/install_kobold.ps1` | Windows | Install/update KoboldAI. | `tests/test_windows_wrappers.py` |
| `launcher/windows/install_kobold.bat` | Windows | Install/update KoboldAI. | `tests/test_windows_wrappers.py` |
| `launcher/windows/install_sillytavern.ps1` | Windows | Install/update SillyTavern. | `tests/test_windows_wrappers.py` |
| `launcher/windows/install_sillytavern.bat` | Windows | Install/update SillyTavern. | `tests/test_windows_wrappers.py` |
| `launcher/windows/install_models.ps1` | Windows | Install/update models into `~/ai-hub/models`. | `tests/test_windows_wrappers.py` |
| `launcher/windows/install_models.bat` | Windows | Install/update models into `~/ai-hub/models`. | `tests/test_windows_wrappers.py` |
| `launcher/windows/download_models_civitai.ps1` | Windows | Download models from CivitAI into `~/ai-hub/models`. | `tests/test_windows_wrappers.py` |
| `launcher/windows/download_models_civitai.bat` | Windows | Download models from CivitAI into `~/ai-hub/models`. | `tests/test_windows_wrappers.py` |
| `launcher/windows/install_loras.ps1` | Windows | Install/update LoRAs into `~/AI/LoRAs`. | `tests/test_windows_wrappers.py` |
| `launcher/windows/install_loras.bat` | Windows | Install/update LoRAs into `~/AI/LoRAs`. | `tests/test_windows_wrappers.py` |
| `launcher/windows/run_webui.ps1` | Windows | Run Stable Diffusion WebUI. | `README.md`, `tests/test_windows_wrappers.py` |
| `launcher/windows/run_webui.bat` | Windows | Run Stable Diffusion WebUI. | `README.md`, `tests/test_windows_wrappers.py` |
| `launcher/windows/run_kobold.ps1` | Windows | Run KoboldAI. | `tests/test_windows_wrappers.py` |
| `launcher/windows/run_kobold.bat` | Windows | Run KoboldAI. | `tests/test_windows_wrappers.py` |
| `launcher/windows/run_sillytavern.ps1` | Windows | Run SillyTavern. | `tests/test_windows_wrappers.py` |
| `launcher/windows/run_sillytavern.bat` | Windows | Run SillyTavern. | `tests/test_windows_wrappers.py` |
| `launcher/windows/run_asr.ps1` | Windows | Run ASR helper. | `tests/test_windows_wrappers.py` |
| `launcher/windows/run_asr.bat` | Windows | Run ASR helper. | `tests/test_windows_wrappers.py` |
| `launcher/windows/run_tts.ps1` | Windows | Run TTS helper. | `tests/test_windows_wrappers.py` |
| `launcher/windows/run_tts.bat` | Windows | Run TTS helper. | `tests/test_windows_wrappers.py` |
| `launcher/windows/run_txt2vid.ps1` | Windows | Run text-to-video helper. | `tests/test_windows_wrappers.py` |
| `launcher/windows/run_txt2vid.bat` | Windows | Run text-to-video helper. | `tests/test_windows_wrappers.py` |
| `launcher/windows/run_img2vid.ps1` | Windows | Run image-to-video helper. | `tests/test_windows_wrappers.py` |
| `launcher/windows/run_img2vid.bat` | Windows | Run image-to-video helper. | `tests/test_windows_wrappers.py` |
| `launcher/windows/performance_flags.ps1` | Windows | Performance flag review (FP16/xFormers/DirectML). | `tests/test_windows_wrappers.py` |
| `launcher/windows/performance_flags.bat` | Windows | Performance flag review (FP16/xFormers/DirectML). | `tests/test_windows_wrappers.py` |
| `launcher/windows/manifest_browser.ps1` | Windows | Manifest browser (curated models/LoRAs). | `tests/test_windows_wrappers.py` |
| `launcher/windows/manifest_browser.bat` | Windows | Manifest browser (curated models/LoRAs). | `tests/test_windows_wrappers.py` |
| `launcher/windows/artifact_maintenance.ps1` | Windows | Artifact maintenance (cleanup/rotation). | `tests/test_windows_wrappers.py` |
| `launcher/windows/artifact_maintenance.bat` | Windows | Artifact maintenance (cleanup/rotation). | `tests/test_windows_wrappers.py` |
| `launcher/windows/artifact_manager.ps1` | Windows | Artifact manager shell helper. | `tests/test_windows_wrappers.py` |
| `launcher/windows/artifact_manager.bat` | Windows | Artifact manager shell helper. | `tests/test_windows_wrappers.py` |
| `launcher/windows/self_update.ps1` | Windows | Self-update bundled installer scripts. | `tests/test_windows_wrappers.py` |
| `launcher/windows/self_update.bat` | Windows | Self-update bundled installer scripts. | `tests/test_windows_wrappers.py` |
| `launcher/windows/pull_updates.ps1` | Windows | `git pull` for cloned checkouts. | `tests/test_windows_wrappers.py` |
| `launcher/windows/pull_updates.bat` | Windows | `git pull` for cloned checkouts. | `tests/test_windows_wrappers.py` |
| `launcher/windows/pair_oobabooga.ps1` | Windows | Pair an oobabooga model with a LoRA. | `tests/test_windows_wrappers.py` |
| `launcher/windows/pair_oobabooga.bat` | Windows | Pair an oobabooga model with a LoRA. | `tests/test_windows_wrappers.py` |
| `launcher/windows/pair_sillytavern.ps1` | Windows | Pick backend + model for SillyTavern. | `tests/test_windows_wrappers.py` |
| `launcher/windows/pair_sillytavern.bat` | Windows | Pick backend + model for SillyTavern. | `tests/test_windows_wrappers.py` |
| `launcher/windows/select_lora.ps1` | Windows | Choose a LoRA preset target. | `tests/test_windows_wrappers.py` |
| `launcher/windows/select_lora.bat` | Windows | Choose a LoRA preset target. | `tests/test_windows_wrappers.py` |
| `launcher/windows/save_pairing.ps1` | Windows | Save the current pairing preset. | `tests/test_windows_wrappers.py` |
| `launcher/windows/save_pairing.bat` | Windows | Save the current pairing preset. | `tests/test_windows_wrappers.py` |
| `launcher/windows/load_pairing.ps1` | Windows | Load a saved pairing preset. | `tests/test_windows_wrappers.py` |
| `launcher/windows/load_pairing.bat` | Windows | Load a saved pairing preset. | `tests/test_windows_wrappers.py` |
| `launcher/windows/save_pairing_preset.ps1` | Windows | Save the current pairing preset. | `tests/test_windows_wrappers.py` |
| `launcher/windows/save_pairing_preset.bat` | Windows | Save the current pairing preset. | `tests/test_windows_wrappers.py` |
| `launcher/windows/load_pairing_preset.ps1` | Windows | Load a saved pairing preset. | `tests/test_windows_wrappers.py` |
| `launcher/windows/load_pairing_preset.bat` | Windows | Load a saved pairing preset. | `tests/test_windows_wrappers.py` |
| `launcher/windows/health_summary.ps1` | Windows | Health summary report. | `tests/test_windows_wrappers.py` |
| `launcher/windows/health_summary.bat` | Windows | Health summary report. | `tests/test_windows_wrappers.py` |
| `launcher/windows/health_webui.ps1` | Windows | Health checks for Stable Diffusion WebUI. | `tests/test_windows_wrappers.py` |
| `launcher/windows/health_webui.bat` | Windows | Health checks for Stable Diffusion WebUI. | `tests/test_windows_wrappers.py` |
| `launcher/windows/health_kobold.ps1` | Windows | Health checks for KoboldAI. | `tests/test_windows_wrappers.py` |
| `launcher/windows/health_kobold.bat` | Windows | Health checks for KoboldAI. | `tests/test_windows_wrappers.py` |
| `launcher/windows/health_sillytavern.ps1` | Windows | Health checks for SillyTavern. | `tests/test_windows_wrappers.py` |
| `launcher/windows/health_sillytavern.bat` | Windows | Health checks for SillyTavern. | `tests/test_windows_wrappers.py` |
| `launcher/windows/launcher_status.ps1` | Windows | Show launcher status panel. | `tests/test_windows_wrappers.py` |
| `launcher/windows/launcher_status.bat` | Windows | Show launcher status panel. | `tests/test_windows_wrappers.py` |

## Windows shared helpers (`launcher/windows/*.ps1`)

These scripts support the PowerShell entrypoints and the Windows action helpers invoked by `launcher/common/aihub_menu.py`.

| Entrypoint | OS | Purpose | References |
| --- | --- | --- | --- |
| `launcher/windows/paths.ps1` | Windows | Shared path helpers for config/log locations. | `launcher/windows/aihub_menu.ps1`, `launcher/windows/start_web_launcher.ps1`, `tools/windows.ps1` |
| `launcher/windows/common.ps1` | Windows | Shared helper for invoking shell actions. | `launcher/windows/*.ps1` action scripts |

## Other helpers that shell out to launchers

| Script | OS | Launcher invoked | References |
| --- | --- | --- | --- |
| `modules/shell/self_update.sh` | Linux/WSL | Relaunches `launcher/linux/aihub_menu.sh` after update. | `modules/shell/self_update.sh` |
| `tools/windows.ps1` | Windows | Calls `install.ps1`, `launcher/windows/aihub_menu.ps1`, `launcher/windows/start_web_launcher.ps1`, and status helpers. | `tools/windows.ps1` |
