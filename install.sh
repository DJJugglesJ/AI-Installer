#!/bin/bash

# install.sh — AI Workstation Setup Launcher
INSTALL_PATH="$HOME/AI-Installer"
CONFIG_FILE="$HOME/.config/aihub/installer.conf"
DESKTOP_ENTRY="$HOME/Desktop/AI-Workstation-Launcher.desktop"

mkdir -p "$INSTALL_PATH"
mkdir -p "$(dirname $CONFIG_FILE)"
mkdir -p "$(dirname $DESKTOP_ENTRY)"

# ✅ Check for required dependencies
bash "$INSTALL_PATH/modules/check_dependencies.sh"

# 🔍 GPU detection
bash "$INSTALL_PATH/modules/detect_gpu.sh"

# 🔧 Track install progress in config file
touch "$CONFIG_FILE"
set_config() {
  key="$1"
  value="$2"
  if grep -q "^$key=" "$CONFIG_FILE"; then
    sed -i "s|^$key=.*|$key=$value|" "$CONFIG_FILE"
  else
    echo "$key=$value" >> "$CONFIG_FILE"
  fi
}

# Example install flow
echo "[*] Running main AI workstation setup..."
# Simulated install steps
set_config "webui_installed" "false"
set_config "kobold_installed" "false"
set_config "loras_installed" "false"
set_config "models_installed" "false"
set_config "gpu_mode" "$(lspci | grep -i 'VGA' | grep -Eo 'NVIDIA|AMD|Intel' | head -n 1 || echo 'CPU')"

# ✅ Create the main desktop launcher
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
