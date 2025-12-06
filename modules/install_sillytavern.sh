#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
mkdir -p "$(dirname "$CONFIG_FILE")"
touch "$CONFIG_FILE"
LOG_FILE="$HOME/.config/aihub/install.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

APP_NAME="SillyTavern"
SILLY_DIR="$HOME/AI/${APP_NAME}"

mkdir -p "$HOME/AI"

if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  echo "$(date): [headless] Preparing ${APP_NAME} install/update..." >> "$LOG_FILE"
else
  yad --info --title="Installing ${APP_NAME}" --text="Preparing ${APP_NAME} install/update..."
  echo "$(date): Preparing ${APP_NAME} install/update..." >> "$LOG_FILE"
fi

if [[ -d "$SILLY_DIR" ]]; then
  echo "$(date): Found existing ${APP_NAME} at ${SILLY_DIR}, pulling latest changes..." >> "$LOG_FILE"
  if git -C "$SILLY_DIR" pull >> "$LOG_FILE" 2>&1; then
    ACTION_RESULT="updated"
    ACTION_STATUS="success"
  else
    ACTION_RESULT="update failed"
    ACTION_STATUS="failure"
  fi
else
  echo "$(date): Cloning ${APP_NAME} into ${SILLY_DIR}..." >> "$LOG_FILE"
  if git clone https://github.com/SillyTavern/SillyTavern "$SILLY_DIR" >> "$LOG_FILE" 2>&1; then
    ACTION_RESULT="installed"
    ACTION_STATUS="success"
  else
    ACTION_RESULT="install failed"
    ACTION_STATUS="failure"
  fi
fi

if [[ "$ACTION_STATUS" == "success" ]]; then
  if grep -q "^sillytavern_installed=" "$CONFIG_FILE"; then
    sed -i 's/^sillytavern_installed=.*/sillytavern_installed=true/' "$CONFIG_FILE"
  else
    echo "sillytavern_installed=true" >> "$CONFIG_FILE"
  fi
fi

if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  if [[ "$ACTION_STATUS" == "success" ]]; then
    echo "$(date): [headless] ${APP_NAME} ${ACTION_RESULT} and config updated." >> "$LOG_FILE"
  else
    echo "$(date): [headless] ${APP_NAME} ${ACTION_RESULT}. Check logs for details." >> "$LOG_FILE"
  fi
else
  if [[ "$ACTION_STATUS" == "success" ]]; then
    yad --info --text="✅ ${APP_NAME} ${ACTION_RESULT} and config updated." --title="Install Complete"
  else
    yad --error --text="❌ ${APP_NAME} ${ACTION_RESULT}. Check logs for details." --title="Install Failed"
  fi
  echo "$(date): install_sillytavern.sh ${ACTION_RESULT}." >> "$LOG_FILE"
fi
