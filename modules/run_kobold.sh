#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
LOG_FILE="$HOME/.config/aihub/install.log"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"
metrics_record_start "kobold"

PROMPT_BUNDLE_PATH="${PROMPT_BUNDLE_PATH:-$HOME/.cache/aihub/prompt_builder/prompt_bundle.json}"

load_prompt_bundle() {
  local path="$PROMPT_BUNDLE_PATH"
  if [ ! -f "$path" ]; then
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    log_event "warn" app=kobold event=prompt_bundle message="jq not available; skipping prompt bundle" path="$path"
    return 1
  fi

  local positive negative loras
  positive=$(jq -r '(.positive_prompt // []) | join(" | ")' "$path")
  negative=$(jq -r '(.negative_prompt // []) | join(" | ")' "$path")
  loras=$(jq -r '(.lora_calls // []) | map(.name + (if (.weight // null) != null then ":" + (.weight|tostring) else "" end) + (if (.trigger // null) != null then ":" + .trigger else "" end)) | join(",")' "$path")

  export PROMPT_BUILDER_POSITIVE="$positive"
  export PROMPT_BUILDER_NEGATIVE="$negative"
  export PROMPT_BUILDER_LORAS="$loras"
  export PROMPT_BUILDER_BUNDLE_PATH="$path"

  log_event "info" app=kobold event=prompt_bundle message="Loaded prompt bundle" path="$path" positive_prompt="$positive" negative_prompt="$negative" loras="$loras"
  return 0
}

GPU_LABEL=${gpu_mode:-"Unknown"}
log_event "info" app=kobold event=launch message="Launching KoboldAI" gpu_mode="$GPU_LABEL"
if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  HEADLESS=1 "$SCRIPT_DIR/health_kobold.sh" >/dev/null
fi

load_prompt_bundle

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
