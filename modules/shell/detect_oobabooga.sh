#!/bin/bash
set -euo pipefail

CONFIG_DIR="${AIHUB_CONFIG_DIR:-$HOME/.config/aihub}"
CONFIG_FILE="$CONFIG_DIR/installer.conf"
OOBA_DIR="$HOME/AI/oobabooga"
MODELS_DIR="$OOBA_DIR/models"
LORAS_DIR="$OOBA_DIR/lora"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"

mkdir -p "$CONFIG_DIR"
touch "$CONFIG_FILE"

# Check for oobabooga installation
if [ ! -d "$OOBA_DIR" ]; then
  yad --error --title="oobabooga Not Found" --text="❌ oobabooga was not found in $OOBA_DIR"
  log_msg "oobabooga not found at $OOBA_DIR"
  exit 1
fi

# List models
MODEL_LIST=$(find "$MODELS_DIR" -type f \( -name "*.bin" -o -name "*.gguf" -o -name "*.pth" -o -name "*.safetensors" \) 2>/dev/null)
LORA_LIST=$(find "$LORAS_DIR" -type f \( -name "*.safetensors" -o -name "*.pt" \) 2>/dev/null)

yad --form --title="oobabooga Detected" --width=500 --height=400 \
  --text="✅ oobabooga found at: $OOBA_DIR\n\n📁 Detected Models:\n$(echo "$MODEL_LIST" | sed 's/^/  - /')\n\n🧩 Detected LoRAs:\n$(echo "$LORA_LIST" | sed 's/^/  - /')" \
  --field="oobabooga path:":RO "$OOBA_DIR"

log_msg "oobabooga detected. Models: $(echo "$MODEL_LIST" | wc -l), LoRAs: $(echo "$LORA_LIST" | wc -l)"
