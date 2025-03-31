#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
mkdir -p "$(dirname "$CONFIG_FILE")"
touch "$CONFIG_FILE"

yad --info --title="Installing SillyTavern" --text="Cloning SillyTavern..."

git clone https://github.com/SillyTavern/SillyTavern ~/AI/SillyTavern

if grep -q "^sillytavern_installed=" "$CONFIG_FILE"; then
  sed -i 's/^sillytavern_installed=.*/sillytavern_installed=true/' "$CONFIG_FILE"
else
  echo "sillytavern_installed=true" >> "$CONFIG_FILE"
fi

yad --info --text="✅ SillyTavern installed and config updated." --title="Install Complete"
