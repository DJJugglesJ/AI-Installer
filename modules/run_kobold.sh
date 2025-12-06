#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
LOG_FILE="$HOME/.config/aihub/install.log"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"
metrics_record_start "kobold"

GPU_LABEL=${gpu_mode:-"Unknown"}
log_event "info" app=kobold event=launch message="Launching KoboldAI" gpu_mode="$GPU_LABEL"
if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  HEADLESS=1 "$SCRIPT_DIR/health_kobold.sh" >/dev/null
fi

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
  log_event "error" app=kobold event=missing_path path="$KOBOLD_DIR" message="KoboldAI folder not found"
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
  log_event "error" app=kobold event=missing_env path="$KOBOLD_DIR" message="No Python environment found"
  exit 1
fi
