#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
mkdir -p "$(dirname "$CONFIG_FILE")"
touch "$CONFIG_FILE"

yad --info --title="Installing KoboldAI" --text="Cloning KoboldAI..."

git clone https://github.com/KoboldAI/KoboldAI-Client ~/AI/KoboldAI

if grep -q "^kobold_installed=" "$CONFIG_FILE"; then
  sed -i 's/^kobold_installed=.*/kobold_installed=true/' "$CONFIG_FILE"
else
  echo "kobold_installed=true" >> "$CONFIG_FILE"
fi

yad --info --text="✅ KoboldAI installed and config updated." --title="Install Complete"
