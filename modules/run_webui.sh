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

WEBUI_DIR="$HOME/AI/WebUI"
GPU_LABEL=${gpu_mode:-"Unknown"}
log_msg "Launching Stable Diffusion WebUI with GPU mode: $GPU_LABEL"

if [ ! -d "$WEBUI_DIR" ]; then
  yad --error --title="WebUI Not Found" --text="Stable Diffusion WebUI folder not found. Please install it first."
  exit 1
fi

cd "$WEBUI_DIR"

# Activate venv
if [ -f "venv/bin/activate" ]; then
  source venv/bin/activate
else
  yad --error --title="Environment Missing" --text="Virtual environment not found. Please reinstall WebUI."
  exit 1
fi

# Determine launch flags
GPU_FLAGS=""
case "$gpu_mode" in
  "NVIDIA")
    GPU_FLAGS="--xformers"
    ;;
  "AMD")
    export HSA_OVERRIDE_GFX_VERSION=10.3.0
    GPU_FLAGS="--precision full --no-half"
    ;;
  "INTEL"|"CPU")
    GPU_FLAGS="--use-cpu all"
    ;;
esac
log_msg "Computed WebUI launch flags: ${GPU_FLAGS:-'(none)'}"

# Launch WebUI with proper flags
python launch.py $GPU_FLAGS
