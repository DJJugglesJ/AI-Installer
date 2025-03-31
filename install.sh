#!/bin/bash

# install.sh — AI Workstation Setup Launcher
INSTALL_PATH="$HOME/AI-Installer"
DESKTOP_ENTRY="$HOME/Desktop/AI-Workstation-Launcher.desktop"

mkdir -p "$INSTALL_PATH"
mkdir -p "$(dirname $DESKTOP_ENTRY)"

# Placeholder for actual module execution logic
echo "[*] Running main AI workstation setup..."
# bash modules/install_webui.sh
# bash modules/install_kobold.sh
# bash modules/install_loras.sh
# bash modules/install_models.sh

# Create the main desktop launcher
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
