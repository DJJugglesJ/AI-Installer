#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
LOG_FILE="$HOME/.config/aihub/install.log"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"
metrics_record_start "webui"

PROMPT_BUNDLE_PATH="${PROMPT_BUNDLE_PATH:-$HOME/.cache/aihub/prompt_builder/prompt_bundle.json}"

load_prompt_bundle() {
  local path="$PROMPT_BUNDLE_PATH"
  if [ ! -f "$path" ]; then
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    log_event "warn" app=webui event=prompt_bundle message="jq not available; skipping prompt bundle" path="$path"
    return 1
  fi

  local positive negative loras
  positive=$(jq -r 'if .positive_prompt_text? then .positive_prompt_text else (.positive_prompt // []) | join(" | ") end' "$path")
  negative=$(jq -r 'if .negative_prompt_text? then .negative_prompt_text else (.negative_prompt // []) | join(" | ") end' "$path")
  loras=$(jq -r '(.lora_calls // []) | map(.name + (if (.weight // null) != null then ":" + (.weight|tostring) else "" end) + (if (.trigger // null) != null then ":" + .trigger else "" end)) | join(",")' "$path")

  export PROMPT_BUILDER_POSITIVE="$positive"
  export PROMPT_BUILDER_NEGATIVE="$negative"
  export PROMPT_BUILDER_LORAS="$loras"
  export PROMPT_BUILDER_BUNDLE_PATH="$path"

  log_event "info" app=webui event=prompt_bundle message="Loaded prompt bundle" path="$path" positive_prompt="$positive" negative_prompt="$negative" loras="$loras"
  return 0
}

normalize_bool() {
  local raw="$1"
  case "${raw,,}" in
    true|1|yes|y|on)
      echo "true"
      ;;
    *)
      echo "false"
      ;;
  esac
}

WEBUI_DIR="$HOME/AI/WebUI"
GPU_LABEL=${gpu_mode:-"Unknown"}
log_event "info" app=webui event=launch message="Launching Stable Diffusion WebUI" gpu_mode="$GPU_LABEL"
if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  HEADLESS_HEALTH=1 HEADLESS=1 "$SCRIPT_DIR/health_webui.sh" >/dev/null
fi

load_prompt_bundle

if [ ! -d "$WEBUI_DIR" ]; then
  if [[ "${HEADLESS:-0}" -eq 1 ]]; then
    log_event "error" app=webui event=missing_path path="$WEBUI_DIR" message="WebUI folder not found"
  else
    yad --error --title="WebUI Not Found" --text="Stable Diffusion WebUI folder not found. Please install it first."
  fi
  exit 1
fi

cd "$WEBUI_DIR"

# Activate venv
if [ -f "venv/bin/activate" ]; then
  source venv/bin/activate
else
  if [[ "${HEADLESS:-0}" -eq 1 ]]; then
    log_event "error" app=webui event=missing_env path="$WEBUI_DIR/venv" message="Virtual environment missing"
  else
    yad --error --title="Environment Missing" --text="Virtual environment not found. Please reinstall WebUI."
  fi
  exit 1
fi

# Determine launch flags
GPU_FLAGS=()
append_flag() { GPU_FLAGS+=("$@"); }

supports_fp16=$(normalize_bool "${gpu_supports_fp16:-false}")
supports_xformers=$(normalize_bool "${gpu_supports_xformers:-false}")
supports_directml=$(normalize_bool "${gpu_supports_directml:-false}")

enable_fp16=$(normalize_bool "${enable_fp16:-false}")
enable_xformers=$(normalize_bool "${enable_xformers:-false}")
enable_directml=$(normalize_bool "${enable_directml:-false}")
enable_low_vram=$(normalize_bool "${enable_low_vram:-false}")

case "$gpu_mode" in
  "AMD")
    export HSA_OVERRIDE_GFX_VERSION=10.3.0
    ;;
  "INTEL"|"CPU")
    append_flag --use-cpu all
    ;;
esac

if [[ "$enable_directml" == "true" ]]; then
  if [[ "$supports_directml" == "true" ]]; then
    append_flag --use-directml
    log_event "info" app=webui event=flag_applied flag="--use-directml" reason="Requested and supported"
    enable_xformers="false"
  else
    log_event "warn" app=webui event=flag_skipped flag="--use-directml" reason="Hardware unsupported"
    enable_directml="false"
  fi
fi

if [[ "$enable_xformers" == "true" ]]; then
  if [[ "$supports_xformers" == "true" ]]; then
    append_flag --xformers
    log_event "info" app=webui event=flag_applied flag="--xformers"
  else
    log_event "warn" app=webui event=flag_skipped flag="--xformers" reason="GPU/driver unsupported"
  fi
fi

if [[ "$enable_fp16" != "true" || "$supports_fp16" != "true" ]]; then
  append_flag --precision full --no-half
  if [[ "$supports_fp16" != "true" ]]; then
    log_event "warn" app=webui event=flag_applied flag="--precision full --no-half" reason="GPU/driver lacks FP16 support"
  else
    log_event "info" app=webui event=flag_applied flag="--precision full --no-half" reason="Config disabled FP16"
  fi
else
  log_event "info" app=webui event=flag_applied flag="fp16" reason="Config enabled and hardware supports"
fi

if [[ "$enable_low_vram" == "true" ]]; then
  append_flag --medvram
  log_event "info" app=webui event=flag_applied flag="--medvram"
fi

log_event "info" app=webui event=launch_flags flags="${GPU_FLAGS[*]:-(none)}"

# Launch WebUI with proper flags
python launch.py "${GPU_FLAGS[@]}"
