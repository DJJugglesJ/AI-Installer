#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

KOBOLD_DIR="$HOME/AI/KoboldAI"

notify_error() {
  local title="$1"
  local message="$2"
  if command -v yad >/dev/null 2>&1; then
    yad --error --title="$title" --text="$message"
  else
    echo "$title: $message" >&2
  fi
}

if [ ! -d "$KOBOLD_DIR" ]; then
  notify_error "KoboldAI Not Found" "KoboldAI folder not found in ~/AI. Please install it first."
  exit 1
fi

cd "$KOBOLD_DIR"

# Attempt to activate a known environment before launching
if [ -f "runtime/envs/koboldai/bin/activate" ]; then
  source "runtime/envs/koboldai/bin/activate"
  python aiserver.py
elif [ -f "venv/bin/activate" ]; then
  source "venv/bin/activate"
  python aiserver.py
elif [ -x "bin/micromamba" ]; then
  ./bin/micromamba run -r runtime -n koboldai python aiserver.py
elif [ -x "./play.sh" ]; then
  bash ./play.sh
else
  notify_error "Environment Missing" "Unable to locate a Python environment for KoboldAI. Please reinstall KoboldAI."
  exit 1
fi
