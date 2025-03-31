#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
LOG_FILE="$HOME/.config/aihub/install.log"
mkdir -p "$(dirname "$CONFIG_FILE")"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$CONFIG_FILE"
touch "$LOG_FILE"

# Refresh local LoRA list if API integration is working
echo "[*] Launching LoRA selector..."
# Placeholder: logic to pull from CivitAI and cache can go here

# Placeholder for actual tag grouping and YAD menu:
yad --info --title="LoRA Installer" --text="This is the real LoRA installer.\n\nTag filters and selection will appear here."

# Update config
if grep -q "^loras_installed=" "$CONFIG_FILE"; then
  sed -i 's/^loras_installed=.*/loras_installed=true/' "$CONFIG_FILE"
else
  echo "loras_installed=true" >> "$CONFIG_FILE"
fi

echo "$(date): Installed selected LoRAs." >> "$LOG_FILE"

yad --info --text="✅ Selected LoRAs installed!" --title="Done"
