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
log_msg "Launching Stable Diffusion WebUI with GPU mode: $GPU_LABEL"

if [ ! -d "$WEBUI_DIR" ]; then
  if [[ "${HEADLESS:-0}" -eq 1 ]]; then
    log_msg "WebUI folder not found at $WEBUI_DIR."
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
    log_msg "Virtual environment missing for WebUI at $WEBUI_DIR."
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
    log_msg "DirectML requested and supported; enabling --use-directml."
    enable_xformers="false"
  else
    log_msg "DirectML requested but not supported by detected hardware; skipping."
    enable_directml="false"
  fi
fi

if [[ "$enable_xformers" == "true" ]]; then
  if [[ "$supports_xformers" == "true" ]]; then
    append_flag --xformers
    log_msg "xFormers acceleration enabled."
  else
    log_msg "xFormers requested but not supported by current GPU/driver; skipping."
  fi
fi

if [[ "$enable_fp16" != "true" || "$supports_fp16" != "true" ]]; then
  append_flag --precision full --no-half
  if [[ "$supports_fp16" != "true" ]]; then
    log_msg "FP16 disabled because GPU/driver does not advertise half-precision stability."
  else
    log_msg "FP16 toggle disabled by config; enforcing full precision."
  fi
else
  log_msg "FP16 enabled; half-precision will be used when supported by WebUI."
fi

if [[ "$enable_low_vram" == "true" ]]; then
  append_flag --medvram
  log_msg "Low VRAM mode enabled via --medvram."
fi

log_msg "Computed WebUI launch flags: ${GPU_FLAGS[*]:-(none)}"

# Launch WebUI with proper flags
python launch.py "${GPU_FLAGS[@]}"
