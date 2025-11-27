#!/bin/bash

# install.sh — AI Workstation Setup Launcher
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PATH="$SCRIPT_DIR"
MODULE_DIR="$INSTALL_PATH/modules"
CONFIG_FILE="$HOME/.config/aihub/installer.conf"
DESKTOP_ENTRY="$HOME/Desktop/AI-Workstation-Launcher.desktop"
LOG_FILE="$HOME/.config/aihub/install.log"

notify_prereq() {
  local message="$1"
  if command -v yad >/dev/null 2>&1; then
    yad --error --title="Missing Prerequisite" --text="$message" --width=400
  else
    echo "[!] $message" >&2
  fi
}

require_commands() {
  local missing=()
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    local joined
    joined=$(IFS=$'\n'; echo "${missing[*]}")
    notify_prereq "The following tools are required before running the installer:\n\n$joined\n\nPlease install them with: sudo apt install ${missing[*]}"
    exit 1
  fi
}

# Ensure we have the basics to prompt and install dependencies before proceeding
require_commands bash dpkg sudo apt

mkdir -p "$INSTALL_PATH"
mkdir -p "$(dirname "$CONFIG_FILE")"
mkdir -p "$(dirname "$DESKTOP_ENTRY")"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$CONFIG_FILE"
touch "$LOG_FILE"

# ✅ Check for required dependencies
bash "$MODULE_DIR/check_dependencies.sh"

# 🔍 GPU detection
CONFIG_FILE="$CONFIG_FILE" bash "$MODULE_DIR/detect_gpu.sh"

# ✅ Create the unified desktop launcher
LAUNCH_CMD="$INSTALL_PATH/aihub_menu.sh"
cat > "$DESKTOP_ENTRY" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=AI Workstation Launcher
Comment=Launch the AI Workstation Menu
Exec=/bin/bash -lc '"$LAUNCH_CMD"'
Icon=utilities-terminal
Terminal=false
Categories=Utility;
EOF

chmod +x "$DESKTOP_ENTRY"
echo "[✔] Desktop launcher created at $DESKTOP_ENTRY"
echo "$(date): Installer launched and launcher created." >> "$LOG_FILE"
