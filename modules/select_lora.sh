#!/bin/bash

LORA_DIR="$HOME/AI/oobabooga/lora"
TMP_SELECTED="/tmp/selected_lora.txt"

mkdir -p "$LORA_DIR"

LORA_FILES=$(find "$LORA_DIR" -type f \( -name "*.safetensors" -o -name "*.pt" \) -exec basename {} \;)

if [ -z "$LORA_FILES" ]; then
  yad --error --title="No LoRAs Found" --text="❌ No LoRA files found in:\n$LORA_DIR"
  exit 1
fi

SELECTED=$(yad --form --title="Select LoRA for Preset" --field="LoRA File:CB" "$(echo "$LORA_FILES" | tr '\n' '!')")

LORA_FILE=$(echo "$SELECTED" | cut -d '|' -f1)

echo "$LORA_FILE" > "$TMP_SELECTED"

yad --info --title="LoRA Selected" --text="✅ LoRA selected:\n$LORA_FILE"
