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

log_msg() {
  echo "$(date): $1" >> "$LOG_FILE"
}

require_commands() {
  local missing=()
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    local joined
    joined=$(IFS=$'\n'; echo "${missing[*]}")
    notify error "Missing prerequisites" "The following commands are required before downloading LoRAs:\n\n$joined"
    exit 1
  fi
}

ensure_downloader() {
  if command -v aria2c >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
    return 0
  fi
  notify error "Downloader missing" "Please install aria2 or wget to continue."
  exit 1
}

verify_checksum() {
  local file="$1" expected="$2"
  if [ -z "$expected" ] || [ "$expected" = "null" ]; then
    log_msg "Checksum not provided for $(basename "$file"); skipping verification"
    return 0
  fi
  local actual
  actual=$(sha256sum "$file" | awk '{print $1}')
  if [ "$actual" != "$expected" ]; then
    notify error "Checksum mismatch" "Expected $expected but found $actual for $(basename "$file")."
    log_msg "Checksum mismatch for $file (expected: $expected, got: $actual); removing corrupt download"
    rm -f "$file"
    return 1
  fi
  log_msg "Checksum verified for $(basename "$file")"
  return 0
}

download_with_retries() {
  local url="$1" dest="$2" expected_checksum="$3"
  local attempt=1 max_attempts=3 backoff=5
  log_msg "Starting download for $dest from $url"

  while [ $attempt -le $max_attempts ]; do
    if [ $attempt -gt 1 ]; then
      notify info "Retrying download" "Attempt $attempt of $max_attempts for $(basename "$dest")"
      log_msg "Retry attempt $attempt for $dest"
      sleep $backoff
      backoff=$((backoff * 2))
    fi

    if command -v aria2c >/dev/null 2>&1; then
      if aria2c --continue=true --max-tries=1 --retry-wait=3 --dir="$(dirname "$dest")" --out="$(basename "$dest")" "$url"; then
        if verify_checksum "$dest" "$expected_checksum"; then
          return 0
        fi
      fi
    elif command -v wget >/dev/null 2>&1; then
      if wget --continue --show-progress --tries=1 --waitretry=3 -O "$dest" "$url"; then
        if verify_checksum "$dest" "$expected_checksum"; then
          return 0
        fi
      fi
    fi

    attempt=$((attempt + 1))
  done

  notify error "Download failed" "Unable to download $(basename "$dest") after $max_attempts attempts."
  log_msg "Download failed after $max_attempts attempts: $dest"
  return 1
}

require_commands yad jq curl sha256sum
ensure_downloader

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
  CHECKSUM=$(echo "$MODEL_DATA" | jq -r '.files[] | select(.type == "Model" and (.name | test("\\.(safetensors|ckpt)$"))) | .hashes.SHA256' | head -n 1)
  EXT=$(basename "$URL" | sed 's/.*\.\(safetensors\|ckpt\)$/\1/')
  OUTNAME=$(echo "$NAME" | tr ' /' '_' | sed 's/[^a-zA-Z0-9_-]//g')
  DEST="$INSTALL_DIR/$OUTNAME.$EXT"

  log_msg "Downloading $OUTNAME.$EXT"
  if ! download_with_retries "$URL" "$DEST" "$CHECKSUM"; then
    echo "$(date): Download failed for $OUTNAME.$EXT" >> "$LOG_FILE"
    continue
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
