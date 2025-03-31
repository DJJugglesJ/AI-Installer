#!/bin/bash

INSTALL_DIR="$HOME/AI-Installer"
LOG_FILE="$HOME/.config/aihub/install.log"

if [ ! -d "$INSTALL_DIR/.git" ]; then
  yad --error --title="Update Failed" --text="❌ This installation wasn't cloned from GitHub.\nSelf-updater is unavailable."
  echo "$(date): Update failed — no .git directory found." >> "$LOG_FILE"
  exit 1
fi

cd "$INSTALL_DIR"
yad --info --title="Updating Installer" --text="🔄 Checking for updates from GitHub..."
git pull

if [ $? -eq 0 ]; then
  echo "$(date): Installer updated via git pull." >> "$LOG_FILE"
  yad --info --title="Update Complete" --text="✅ AI Installer has been updated. Relaunching..."
  exec bash "$INSTALL_DIR/aihub_menu.sh"
else
  echo "$(date): Git pull failed." >> "$LOG_FILE"
  yad --error --title="Update Failed" --text="❌ Git pull failed.\nCheck your internet connection or repository state."
fi
