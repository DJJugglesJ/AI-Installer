#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
LOG_FILE="$HOME/.config/aihub/install.log"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log_msg() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$LOG_FILE"
}

GPU_LABEL=${gpu_mode:-"Unknown"}
log_msg "Launching SillyTavern with GPU mode: $GPU_LABEL"

SILLY_DIR="$HOME/AI/SillyTavern"

notify_error() {
  local title="$1"
  local message="$2"
  if command -v yad >/dev/null 2>&1; then
    yad --error --title="$title" --text="$message"
  else
    echo "$title: $message" >&2
  fi
}

notify_info() {
  local title="$1"
  local message="$2"
  if command -v yad >/dev/null 2>&1; then
    yad --info --title="$title" --text="$message"
  else
    echo "$title: $message"
  fi
}

if [ ! -d "$SILLY_DIR" ]; then
  notify_error "SillyTavern Not Found" "SillyTavern folder not found in ~/AI. Please install it first."
  exit 1
fi

cd "$SILLY_DIR"

if [ -x "./start.sh" ]; then
  bash ./start.sh
  exit $?
fi

if ! command -v npm >/dev/null 2>&1; then
  notify_error "Node.js Missing" "npm was not found on this system. Please install Node.js before launching SillyTavern."
  exit 1
fi

if [ ! -d "node_modules" ]; then
  notify_info "Installing Dependencies" "Installing SillyTavern dependencies..."
  export NODE_ENV=production
  if ! npm i --no-audit --no-fund --loglevel=error --no-progress --omit=dev; then
    notify_error "Install Failed" "Failed to install npm dependencies for SillyTavern."
    exit 1
  fi
fi

node server.js
