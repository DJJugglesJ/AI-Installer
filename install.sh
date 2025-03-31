#!/bin/bash

# install.sh — AI Workstation Setup Launcher
INSTALL_PATH="$HOME/AI-Installer"
CONFIG_FILE="$HOME/.config/aihub/installer.conf"
DESKTOP_ENTRY="$HOME/Desktop/AI-Workstation-Launcher.desktop"
LOG_FILE="$HOME/.config/aihub/install.log"

mkdir -p "$INSTALL_PATH"
mkdir -p "$(dirname $CONFIG_FILE)"
mkdir -p "$(dirname $DESKTOP_ENTRY)"
mkdir -p "$(dirname $LOG_FILE)"
touch "$CONFIG_FILE"
touch "$LOG_FILE"

# ✅ Check for required dependencies
bash "$INSTALL_PATH/modules/check_dependencies.sh"

# 🔍 GPU detection
bash "$INSTALL_PATH/modules/detect_gpu.sh"

# 🧠 Save GPU mode to config
if grep -q "^gpu_mode=" "$CONFIG_FILE"; then
  sed -i "s/^gpu_mode=.*/gpu_mode=$(lspci | grep -i 'VGA' | grep -Eo 'NVIDIA|AMD|Intel' | head -n 1 || echo 'CPU')/" "$CONFIG_FILE"
else
  echo "gpu_mode=$(lspci | grep -i 'VGA' | grep -Eo 'NVIDIA|AMD|Intel' | head -n 1 || echo 'CPU')" >> "$CONFIG_FILE"
fi

# ✅ Create the unified desktop launcher
cat > "$DESKTOP_ENTRY" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=AI Workstation Launcher
Comment=Launch the AI Workstation Menu
Exec=bash $INSTALL_PATH/aihub_menu.sh
Icon=utilities-terminal
Terminal=false
Categories=Utility;
EOF

chmod +x "$DESKTOP_ENTRY"
echo "[✔] Desktop launcher created at $DESKTOP_ENTRY"
echo "$(date): Installer launched and launcher created." >> "$LOG_FILE"
