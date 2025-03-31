#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

WEBUI_DIR="$HOME/AI/WebUI"

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

# Launch WebUI with proper flags
python launch.py $GPU_FLAGS
