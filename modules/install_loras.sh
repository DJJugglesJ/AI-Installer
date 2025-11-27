#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$HOME/.config/aihub/installer.conf"
LOG_FILE="$HOME/.config/aihub/install.log"
TMP_FILTERED="/tmp/civitai_loras.json"
TMP_SELECTED_TAGS="/tmp/lora_selected_tags.txt"
TMP_MATCHES="/tmp/lora_filtered_results.txt"
TMP_SOURCE_INFO="/tmp/civitai_lora_source.txt"
INSTALL_DIR="$HOME/AI/LoRAs"

notify()
{
  local type="$1"
  local title="$2"
  local message="$3"
  if command -v yad >/dev/null 2>&1; then
    case "$type" in
      error) yad --error --title="$title" --text="$message" ;;
      info) yad --info --title="$title" --text="$message" ;;
    esac
  else
    case "$type" in
      error) echo "ERROR: $title - $message" >&2 ;;
      info) echo "$title: $message" ;;
    esac
  fi
}

mkdir -p "$(dirname "$CONFIG_FILE")"
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$INSTALL_DIR"
touch "$CONFIG_FILE"
touch "$LOG_FILE"

# Run tag filter and LoRA filter
if ! bash "$SCRIPT_DIR/tag_filter_dynamic.sh"; then
  notify error "Tag Retrieval Failed" "Unable to fetch the latest LoRA list. Please check your connection and try again."
  exit 1
fi

if [ ! -s "$TMP_FILTERED" ]; then
  notify error "No Data" "No LoRA data was returned from Civitai."
  exit 1
fi

if ! jq -e '.items' "$TMP_FILTERED" >/dev/null 2>&1; then
  notify error "Invalid Data" "Received malformed data from Civitai."
  exit 1
fi

# Save filtered results for download menu
FILTERED=()
> "$TMP_MATCHES"

SELECTED_TAGS=()
if [ -f "$TMP_SELECTED_TAGS" ]; then
  mapfile -t SELECTED_TAGS < "$TMP_SELECTED_TAGS"
fi
SOURCE_NOTE="Source: CivitAI LoRAs"
if [ -f "$TMP_SOURCE_INFO" ]; then
  SOURCE_NOTE=$(cat "$TMP_SOURCE_INFO")
fi

while IFS= read -r item; do
  name=$(echo "$item" | jq -r .name)
  tags=$(echo "$item" | jq -r '.tags | join(",")')
  match=true
  if [ ${#SELECTED_TAGS[@]} -gt 0 ]; then
    for tag in "${SELECTED_TAGS[@]}"; do
      tag=${tag//[$'\r\n']/}
      [ -z "$tag" ] && continue
      if [[ ",$tags," != *",$tag,"* ]]; then
        match=false
        break
      fi
    done
  fi
  if $match; then
    FILTERED+=("$name" "$tags")
    echo "$item" >> "$TMP_MATCHES"
  fi
done < <(jq -c '.items[]' "$TMP_FILTERED")

if [ ${#FILTERED[@]} -eq 0 ]; then
  notify info "No Matches" "No LoRAs matched the selected tags."
  exit 0
fi

# Show filtered LoRAs and allow user to pick which to download
CHOICE=$(yad --list --width=600 --height=400 --title="Select LoRAs to Download" \
  --text="$SOURCE_NOTE" \
  --multiple --separator="|" \
  --column="Name" --column="Tags" "${FILTERED[@]}")

# Download selected LoRAs
if [ -z "$CHOICE" ]; then
  notify info "Cancelled" "No LoRAs were selected for download."
  exit 0
fi

IFS="|" read -r -a NAMES <<< "$CHOICE"

for NAME in "${NAMES[@]}"; do
  NAME=${NAME//[$'\r\n']/}
  [ -z "$NAME" ] && continue
  JSON=$(jq -c --arg name "$NAME" 'select(.name == $name)' "$TMP_MATCHES" | head -n 1)
  if [ -z "$JSON" ]; then
    echo "$(date): Skipped $NAME — metadata not found." >> "$LOG_FILE"
    continue
  fi
  ID=$(echo "$JSON" | jq -r .id)
  if [ -z "$ID" ] || [ "$ID" = "null" ]; then
    echo "$(date): Skipped $NAME — missing model ID." >> "$LOG_FILE"
    continue
  fi
  if ! MODEL_DATA=$(curl -fsS "https://civitai.com/api/v1/model-versions/$ID"); then
    notify error "Download Failed" "Could not fetch metadata for $NAME."
    echo "$(date): Failed to fetch metadata for $NAME (ID: $ID)." >> "$LOG_FILE"
    continue
  fi
  URL=$(echo "$MODEL_DATA" | jq -r '.files[] | select(.type == "Model" and (.name | test("\\.(safetensors|ckpt)$"))) | .downloadUrl' | head -n 1)
  if [ -z "$URL" ] || [ "$URL" = "null" ]; then
    notify error "Download Failed" "No downloadable file found for $NAME."
    echo "$(date): No downloadable file for $NAME (ID: $ID)." >> "$LOG_FILE"
    continue
  fi
  EXT=$(basename "$URL" | sed 's/.*\.\(safetensors\|ckpt\)$/\1/')
  OUTNAME=$(echo "$NAME" | tr ' /' '_' | sed 's/[^a-zA-Z0-9_-]//g')
  DEST="$INSTALL_DIR/$OUTNAME.$EXT"

  echo "$(date): Downloading $OUTNAME.$EXT" >> "$LOG_FILE"
  if command -v aria2c >/dev/null 2>&1; then
    if ! aria2c --continue=true --max-tries=5 --retry-wait=5 --dir="$INSTALL_DIR" --out="$OUTNAME.$EXT" "$URL"; then
      notify error "Download Failed" "Unable to download $NAME."
      echo "$(date): Download failed for $OUTNAME.$EXT" >> "$LOG_FILE"
      continue
    fi
  else
    if ! wget --continue --show-progress -O "$DEST" "$URL"; then
      notify error "Download Failed" "Unable to download $NAME."
      echo "$(date): Download failed for $OUTNAME.$EXT" >> "$LOG_FILE"
      continue
    fi
  fi
  echo "$(date): Downloaded $OUTNAME.$EXT" >> "$LOG_FILE"
done

# Update config
if grep -q "^loras_installed=" "$CONFIG_FILE"; then
  sed -i 's/^loras_installed=.*/loras_installed=true/' "$CONFIG_FILE"
else
  echo "loras_installed=true" >> "$CONFIG_FILE"
fi

echo "$(date): LoRA selection and download completed." >> "$LOG_FILE"
notify info "LoRA Download Complete" "✅ Selected LoRAs downloaded to $INSTALL_DIR"
