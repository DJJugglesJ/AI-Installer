#!/bin/bash

PRESET_DIR="$HOME/.config/aihub/presets"
TMP_LAUNCH="/tmp/st_llm_launch.sh"

mkdir -p "$PRESET_DIR"

PRESET_FILES=("$PRESET_DIR"/*.json)

if [ ${#PRESET_FILES[@]} -eq 0 ]; then
  yad --error --title="No Presets Found" --text="❌ No saved pairings found in $PRESET_DIR"
  exit 1
fi

# Build YAD list format
YAD_ITEMS=()
for file in "${PRESET_FILES[@]}"; do
  NAME=$(jq -r .name "$file")
  BACKEND=$(jq -r .backend "$file")
  MODEL=$(jq -r .model "$file")
  LORA=$(jq -r .lora "$file")
  NOTES=$(jq -r .notes "$file")
  FAV=$(jq -r .favorite "$file")
  YAD_ITEMS+=("$NAME" "$BACKEND" "$MODEL" "$LORA" "$NOTES" "$FAV")
done

SELECTED=$(yad --list --width=800 --height=400 --title="Saved Pairings" \
  --column="Name" --column="Backend" --column="Model" --column="LoRA" --column="Notes" --column="Favorite" \
  "${YAD_ITEMS[@]}")

if [ -z "$SELECTED" ]; then exit 0; fi

# Extract chosen preset name
SELECTED_NAME=$(echo "$SELECTED" | cut -d '|' -f1)
PRESET_PATH="$PRESET_DIR/$(ls "$PRESET_DIR" | grep -i "^${SELECTED_NAME// /_}.*\.json$" | head -n1)"

if [ ! -f "$PRESET_PATH" ]; then
  yad --error --title="Missing File" --text="❌ Could not locate the selected preset file."
  exit 1
fi

# Read preset
BACKEND=$(jq -r .backend "$PRESET_PATH")
MODEL=$(jq -r .model "$PRESET_PATH")
PORT=$(jq -r .port "$PRESET_PATH")
LORA=$(jq -r .lora "$PRESET_PATH")

echo "#!/bin/bash" > "$TMP_LAUNCH"
if [[ "$BACKEND" == "oobabooga" ]]; then
  echo "cd ~/AI/oobabooga" >> "$TMP_LAUNCH"
  echo "python server.py --model-dir models --model "$MODEL"" >> "$TMP_LAUNCH"
elif [[ "$BACKEND" == "KoboldAI" ]]; then
  echo "cd ~/AI/KoboldAI" >> "$TMP_LAUNCH"
  echo "python KoboldAI.py --model "$MODEL"" >> "$TMP_LAUNCH"
fi
chmod +x "$TMP_LAUNCH"

yad --question --title="Launch Preset" --text="✅ Pairing loaded:\n\nModel: $MODEL\nBackend: $BACKEND\n\nLaunch now?" --button="Launch:0" --button="Cancel:1"

if [ $? -eq 0 ]; then
  gnome-terminal -- bash -c "$TMP_LAUNCH; exec bash"
fi
