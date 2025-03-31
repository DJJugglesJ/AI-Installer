#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
LOG_FILE="$HOME/.config/aihub/install.log"
TMP_FILTERED="/tmp/civitai_loras.json"
TMP_SELECTED_TAGS="/tmp/lora_selected_tags.txt"
TMP_MATCHES="/tmp/lora_filtered_results.txt"
INSTALL_DIR="$HOME/AI/LoRAs"

mkdir -p "$(dirname "$CONFIG_FILE")"
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$INSTALL_DIR"
touch "$CONFIG_FILE"
touch "$LOG_FILE"

# Run tag filter and LoRA filter
bash "$HOME/AI-Installer/modules/tag_filter_dynamic.sh"

# Save filtered results for download menu
FILTERED=()
jq -c '.items[]' "$TMP_FILTERED" | while read -r item; do
  name=$(echo "$item" | jq -r .name)
  tags=$(echo "$item" | jq -r '.tags | join(",")')
  match=true
  while read tag; do
    [[ "$tags" == *"$tag"* ]] || match=false
  done < "$TMP_SELECTED_TAGS"
  if $match; then
    FILTERED+=("$name\n$tags")
    echo "$item" >> "$TMP_MATCHES"
  fi
done

# Show filtered LoRAs and allow user to pick which to download
CHOICE=$(yad --list --width=600 --height=400 --title="Select LoRAs to Download" \
  --multiple --separator="|" \
  --column="Name" --column="Tags" "${FILTERED[@]}")

# Download selected LoRAs
IFS="|" read -ra NAMES <<< "$CHOICE"
for NAME in "${NAMES[@]}"; do
  JSON=$(jq -c --arg name "$NAME" '.items[] | select(.name == $name)' "$TMP_MATCHES" | head -n 1)
  ID=$(echo "$JSON" | jq -r .id)
  MODEL_DATA=$(curl -s "https://civitai.com/api/v1/model-versions/$ID")
  URL=$(echo "$MODEL_DATA" | jq -r '.files[] | select(.type == "Model" and (.name | test("\\.(safetensors|ckpt)$"))) | .downloadUrl')
  EXT=$(basename "$URL" | sed 's/.*\.\(safetensors\|ckpt\)$/\1/')
  OUTNAME=$(echo "$NAME" | tr ' /' '_' | sed 's/[^a-zA-Z0-9_-]//g')

  if [[ -n "$URL" ]]; then
    echo "Downloading $OUTNAME.$EXT"
    wget -q --show-progress -O "$INSTALL_DIR/$OUTNAME.$EXT" "$URL"
    echo "$(date): Downloaded $OUTNAME.$EXT" >> "$LOG_FILE"
  fi
done

# Update config
if grep -q "^loras_installed=" "$CONFIG_FILE"; then
  sed -i 's/^loras_installed=.*/loras_installed=true/' "$CONFIG_FILE"
else
  echo "loras_installed=true" >> "$CONFIG_FILE"
fi

echo "$(date): LoRA selection and download completed." >> "$LOG_FILE"
yad --info --title="LoRA Download Complete" --text="✅ Selected LoRAs downloaded to $INSTALL_DIR"
