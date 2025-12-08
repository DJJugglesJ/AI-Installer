# Desktop shortcuts and launchers

The installer generates OS-aware shortcuts for the menu and web UI launchers so users can open the same experience from their desktop environment.

## How targets are chosen
- The installer prefers the web launcher (`launcher/start_web_launcher.sh`) and falls back to the YAD menu (`./aihub_menu.sh`) when the web script is missing. Set `AIHUB_LAUNCHER_MODE=menu` to force the legacy menu.
- Platform and desktop environment detection is logged (`install.log`) to help verify where shortcuts were written.

## Linux
- Primary `.desktop` file: `${XDG_DATA_HOME:-$HOME/.local/share}/applications/ai-hub-launcher.desktop`.
- Convenience copy: `~/Desktop/AI Hub Launcher.desktop` when the desktop directory exists.
- Shortcuts run `/bin/bash -lc "<launcher>"` without opening a terminal and use the system utility icon.
- Remove shortcuts: delete the two files above. Re-running the installer will recreate them.

## Windows (native vs WSL/ROCm)
- GPU-aware selection:
  - NVIDIA: native PowerShell (`launcher/start_web_launcher.ps1` or `launcher/aihub_menu.ps1`) and batch wrappers are copied to the Windows Desktop and Start Menu. `.lnk` files point directly at PowerShell with `-ExecutionPolicy Bypass` so the launcher runs without WSL.
  - AMD (and other vendors): WSL2 is preferred to reach ROCm-ready launchers. Shortcuts call `wsl.exe -e bash -lc "cd <repo> && <launcher>"` and copy helper `.bat`/`.ps1` wrappers alongside the `.lnk` files.
- Prerequisites: `powershell.exe` must support COM automation for `.lnk` creation, and `wsl.exe`/`wslpath` must be available when using the WSL strategy. The installer logs which strategy was used and the detected GPU vendor.
- Paths: desktop helpers are written to the Windows Desktop and Start Menu (`%PROGRAMS%`) paths resolved through PowerShell, with Linux-side copies of the scripts when WSL is involved.
- Remove shortcuts: delete the `.lnk`, `.bat`, and `.ps1` files in the desktop and Start Menu folders.

## macOS
- Desktop command: `~/Desktop/AI-Hub-Launcher.command`.
- App bundle: `~/Applications/AI Hub Launcher.app` with `aihub_launcher` as the executable.
- Both wrappers `cd` into the repository and run the selected launcher script.
- Remove shortcuts: delete the `.command` file and the `.app` directory.

## Cleanup and updates
- The installer prunes legacy shortcuts named `AI-Workstation-Launcher.desktop`, `AI-Hub-Launcher.bat`, and `AI-Hub-Launcher.ps1` before writing new ones.
- Re-running the installer refreshes shortcuts with the latest launcher target and platform detection info.
