#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
mkdir -p "$(dirname "$CONFIG_FILE")"
touch "$CONFIG_FILE"
LOG_FILE="$HOME/.config/aihub/install.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

APP_NAME="SillyTavern"

yad --info --title="Installing ${APP_NAME}" --text="Cloning ${APP_NAME}..."

echo "$(date): Cloning ${APP_NAME}..." >> "$LOG_FILE"
git clone https://github.com/SillyTavern/SillyTavern ~/AI/${APP_NAME}

if grep -q "^sillytavern_installed=" "$CONFIG_FILE"; then
  sed -i 's/^sillytavern_installed=.*/sillytavern_installed=true/' "$CONFIG_FILE"
else
  echo "sillytavern_installed=true" >> "$CONFIG_FILE"
fi

yad --info --text="✅ ${APP_NAME} installed and config updated." --title="Install Complete"

echo "$(date): install_sillytavern.sh installation completed." >> "$LOG_FILE"
