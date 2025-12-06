#!/bin/bash

PRESET_DIR="$HOME/.config/aihub/presets"
PAIR_FILE="/tmp/st_llm_pair.txt"
mkdir -p "$PRESET_DIR"

if [ ! -f "$PAIR_FILE" ]; then
  yad --error --title="No Pairing Found" --text="❌ No pairing has been created yet.\nRun a pairing script first."
  exit 1
fi

# Read pairing values
PAIR=$(cat "$PAIR_FILE")
BACKEND=$(echo "$PAIR" | cut -d ':' -f1)
MODEL=$(echo "$PAIR" | cut -d ':' -f2)
PORT="5000"
[[ "$BACKEND" == "KoboldAI" ]] && PORT="5001"

# Prompt for preset name and notes
FORM=$(yad --form --title="Save Pairing Preset"   --field="Preset Name":TXT ""   --field="Add Notes (optional)":TXT ""   --field="Mark as Favorite:CHK" "FALSE")

PRESET_NAME=$(echo "$FORM" | cut -d '|' -f1)
NOTES=$(echo "$FORM" | cut -d '|' -f2)
FAVORITE=$(echo "$FORM" | cut -d '|' -f3)

if [[ -z "$PRESET_NAME" ]]; then
  yad --error --title="Missing Name" --text="Preset name cannot be empty."
  exit 1
fi

TIMESTAMP=$(date -Iseconds)
PRESET_FILE="$PRESET_DIR/$(echo "$PRESET_NAME" | tr ' ' '_' | tr -cd '[:alnum:]_-').json"

# Build JSON
jq -n   --arg name "$PRESET_NAME"   --arg backend "$BACKEND"   --arg model "$MODEL"   --arg port "$PORT"   --arg lora ""   --arg notes "$NOTES"   --argjson favorite "$FAVORITE"   --arg created "$TIMESTAMP"   '{
    name: $name,
    backend: $backend,
    model: $model,
    lora: $lora,
    port: ($port | tonumber),
    notes: $notes,
    favorite: $favorite,
    created: $created
  }' > "$PRESET_FILE"

yad --info --title="Preset Saved" --text="✅ Pairing saved as:\n$PRESET_FILE"
