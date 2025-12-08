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

## Windows (WSL)
- Desktop helpers: batch (`AI-Hub-Launcher.bat`) and PowerShell (`AI-Hub-Launcher.ps1`) on the Windows desktop path resolved via WSL.
- Start Menu entries: `.lnk` files under `%PROGRAMS%` (Start Menu \> Programs) alongside a desktop `.lnk`.
- Shortcuts use `wsl.exe -e bash -lc "cd <repo> && <launcher>"` so they open the same target as Linux/macOS.
- Remove shortcuts: delete the `.lnk`, `.bat`, and `.ps1` files in the desktop and Start Menu folders.

## macOS
- Desktop command: `~/Desktop/AI-Hub-Launcher.command`.
- App bundle: `~/Applications/AI Hub Launcher.app` with `aihub_launcher` as the executable.
- Both wrappers `cd` into the repository and run the selected launcher script.
- Remove shortcuts: delete the `.command` file and the `.app` directory.

## Cleanup and updates
- The installer prunes legacy shortcuts named `AI-Workstation-Launcher.desktop`, `AI-Hub-Launcher.bat`, and `AI-Hub-Launcher.ps1` before writing new ones.
- Re-running the installer refreshes shortcuts with the latest launcher target and platform detection info.
