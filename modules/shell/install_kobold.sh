#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
CONFIG_STATE_FILE="${CONFIG_STATE_FILE:-$HOME/.config/aihub/config.yaml}"
LOG_FILE="$HOME/.config/aihub/install.log"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config_service/config_helpers.sh"

CONFIG_ENV_FILE="$CONFIG_FILE" CONFIG_STATE_FILE="$CONFIG_STATE_FILE" config_load
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  echo "$(date): [headless] Installing KoboldAI..." >> "$LOG_FILE"
else
  yad --info --title="Installing KoboldAI" --text="Cloning KoboldAI..."
  echo "$(date): Cloning Kobold..." >> "$LOG_FILE"
fi
git clone https://github.com/KoboldAI/KoboldAI-Client ~/AI/KoboldAI

config_set "state.kobold_installed" "true"

if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  echo "$(date): [headless] KoboldAI installed and config updated." >> "$LOG_FILE"
else
  yad --info --text="✅ KoboldAI installed and config updated." --title="Install Complete"
  echo "$(date): install_kobold.sh installation completed." >> "$LOG_FILE"
fi
