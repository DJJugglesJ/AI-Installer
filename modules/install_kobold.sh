#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
mkdir -p "$(dirname "$CONFIG_FILE")"
touch "$CONFIG_FILE"
LOG_FILE="$HOME/.config/aihub/install.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  echo "$(date): [headless] Installing KoboldAI..." >> "$LOG_FILE"
else
  yad --info --title="Installing KoboldAI" --text="Cloning KoboldAI..."
  echo "$(date): Cloning Kobold..." >> "$LOG_FILE"
fi
git clone https://github.com/KoboldAI/KoboldAI-Client ~/AI/KoboldAI

if grep -q "^kobold_installed=" "$CONFIG_FILE"; then
  sed -i 's/^kobold_installed=.*/kobold_installed=true/' "$CONFIG_FILE"
else
  echo "kobold_installed=true" >> "$CONFIG_FILE"
fi

if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  echo "$(date): [headless] KoboldAI installed and config updated." >> "$LOG_FILE"
else
  yad --info --text="✅ KoboldAI installed and config updated." --title="Install Complete"
  echo "$(date): install_kobold.sh installation completed." >> "$LOG_FILE"
fi
