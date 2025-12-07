#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$HOME/.config/aihub/installer.conf"
CONFIG_STATE_FILE="${CONFIG_STATE_FILE:-$HOME/.config/aihub/config.yaml}"
LOG_FILE="$HOME/.config/aihub/install.log"
TMP_FILTERED="/tmp/civitai_loras.json"
TMP_SELECTED_TAGS="/tmp/lora_selected_tags.txt"
TMP_MATCHES="/tmp/lora_filtered_results.txt"
TMP_SOURCE_INFO="/tmp/civitai_lora_source.txt"
INSTALL_DIR="$HOME/AI/LoRAs"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"
LORA_MANIFEST="$MANIFEST_DIR/loras.json"
FORCE_CURATED_SELECTION=0

[ -n "${CURATED_LORA_NAMES:-}" ] && FORCE_CURATED_SELECTION=1

source "$SCRIPT_DIR/../config_service/config_helpers.sh"
CONFIG_ENV_FILE="$CONFIG_FILE" CONFIG_STATE_FILE="$CONFIG_STATE_FILE" config_load

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

log_msg "LoRA installer starting; logging to $LOG_FILE"

human_size() {
  local size_bytes="$1"
  local units=(B KB MB GB TB)
  local unit=0
  local value="$size_bytes"

  while [ "$value" -ge 1024 ] && [ $unit -lt 4 ]; do
    value=$((value / 1024))
    unit=$((unit + 1))
  done

  printf "%s %s" "$value" "${units[$unit]}"
}

offer_backup() {
  local backup_dir="$HOME/.config/aihub/backups/$(date +%Y%m%d%H%M%S)"
  local files_to_backup=()

  [ -f "$CONFIG_FILE" ] && files_to_backup+=("$CONFIG_FILE")
  [ -f "$LOG_FILE" ] && files_to_backup+=("$LOG_FILE")
  [ -f "$LORA_MANIFEST" ] && files_to_backup+=("$LORA_MANIFEST")

  [ ${#files_to_backup[@]} -eq 0 ] && return

  if command -v yad >/dev/null 2>&1; then
    if yad --question --title="Backup files" --text="Create a backup of installer config and LoRA manifest before changes?"; then
      mkdir -p "$backup_dir"
      cp "${files_to_backup[@]}" "$backup_dir/"
      log_msg "Backed up manifest/config to $backup_dir"
    fi
  else
    read -rp "Backup manifest/config before installing? [y/N]: " answer
    case "$answer" in
      [Yy]*)
        mkdir -p "$backup_dir"
        cp "${files_to_backup[@]}" "$backup_dir/"
        log_msg "Backed up manifest/config to $backup_dir"
        ;;
    esac
  fi
}

require_commands() {
  local missing=()
  declare -A remediation
  remediation["jq"]="Install jq: sudo apt install jq"
  remediation["python3"]="Install Python 3: sudo apt install python3"
  remediation["sha256sum"]="Install coreutils/sha256sum: sudo apt install coreutils"
  remediation["aria2c"]="Install aria2: sudo apt install aria2"
  remediation["wget"]="Install wget: sudo apt install wget"
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd — ${remediation[$cmd]:-Install via your package manager}")
    else
      log_msg "Prerequisite check passed for $cmd"
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    local joined
    joined=$(IFS=$'\n'; echo "${missing[*]}")
    notify error "Missing prerequisites" "The following commands are required before downloading LoRAs:\n\n$joined\n\nHelp: https://github.com/AI-Hub/AI-Hub#prerequisites"
    exit 1
  fi
}

ensure_downloader() {
  local has_aria=0 has_wget=0
  command -v aria2c >/dev/null 2>&1 && has_aria=1
  command -v wget >/dev/null 2>&1 && has_wget=1

  if [[ $has_aria -eq 0 && $has_wget -eq 0 ]]; then
    notify error "Downloader missing" "Please install aria2 and/or wget to continue.\n\nExamples:\n  sudo apt-get install aria2\n  sudo apt-get install wget"
    exit 1
  fi

  if [[ $has_aria -eq 0 ]]; then
    notify warning "aria2c unavailable" "Falling back to wget for downloads. Install aria2 for faster parallel downloads:\n  sudo apt-get install aria2"
    log_msg "aria2c missing; using wget fallback"
  fi

  if [[ $has_wget -eq 0 ]]; then
    notify warning "wget unavailable" "Falling back to aria2c for downloads. Install wget for compatibility:\n  sudo apt-get install wget"
    log_msg "wget missing; using aria2c fallback"
  fi
}

run_downloader() {
  local tool="$1" url="$2" dest="$3"
  case "$tool" in
    aria2c)
      aria2c --continue=true --max-tries=1 --retry-wait=3 --dir="$(dirname "$dest")" --out="$(basename "$dest")" "$url"
      ;;
    wget)
      wget --continue --show-progress --tries=1 --waitretry=3 -O "$dest" "$url"
      ;;
    *)
      return 1
      ;;
  esac
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
  local url="$1" dest="$2" expected_checksum="$3" mirror_list="$4"
  local downloaders=()
  local max_attempts=3
  local backoff_start=5
  local urls=("$url")
  local current_url=""

  if [[ -n "$mirror_list" ]]; then
    while IFS= read -r mirror; do
      [[ -n "$mirror" ]] && urls+=("$mirror")
    done <<< "$mirror_list"
  fi

  command -v aria2c >/dev/null 2>&1 && downloaders+=(aria2c)
  command -v wget >/dev/null 2>&1 && downloaders+=(wget)

  for current_url in "${urls[@]}"; do
    log_msg "Starting download: $dest from $current_url using ${downloaders[*]}"
    for ((i = 0; i < ${#downloaders[@]}; i++)); do
      local downloader="${downloaders[$i]}"
      local attempt=1
      local backoff=$backoff_start

      while [ $attempt -le $max_attempts ]; do
        if [ $attempt -gt 1 ]; then
          notify info "Retrying download" "Attempt $attempt of $max_attempts for $(basename "$dest") using $downloader"
          log_msg "Retry attempt $attempt for $dest with $downloader (url: $current_url)"
          sleep $backoff
          backoff=$((backoff * 2))
        fi

        if run_downloader "$downloader" "$current_url" "$dest"; then
          if verify_checksum "$dest" "$expected_checksum"; then
            log_msg "Download succeeded with $downloader from $current_url"
            return 0
          fi
        fi

        attempt=$((attempt + 1))
      done

      if [ $((i + 1)) -lt ${#downloaders[@]} ]; then
        notify warning "Switching downloader" "Initial attempts with $downloader failed. Trying ${downloaders[$((i + 1))]} as a fallback."
        log_msg "$downloader exhausted; switching to ${downloaders[$((i + 1))]}"
      fi
    done

    notify warning "Trying mirror" "Switching to next mirror for $(basename "$dest")"
    log_msg "Primary URL failed for $dest; moving to mirror"
  done

  notify error "Download failed" "Unable to download $(basename "$dest") after trying mirrors and downloaders."
  log_msg "Download failed after attempting ${downloaders[*]} and mirrors: $dest"
  return 1
}

download_manifest_lora() {
  local item="$1"
  local name url filename checksum size mirrors
  name=$(echo "$item" | jq -r '.name')
  url=$(echo "$item" | jq -r '.url')
  filename=$(echo "$item" | jq -r '.filename')
  checksum=$(echo "$item" | jq -r '.checksum')
  mirrors=$(echo "$item" | jq -r '.mirrors[]?')
  size=$(echo "$item" | jq -r '.size_bytes // 0')

  if [ -z "$url" ] || [ -z "$filename" ]; then
    log_msg "Skipping $name due to missing URL or filename"
    return 1
  fi

  notify info "Downloading $name" "Version: $(echo "$item" | jq -r '.version')\nSize: $(human_size "$size")\nLicense: $(echo "$item" | jq -r '.license')"
  local dest="$INSTALL_DIR/$filename"
  if download_with_retries "$url" "$dest" "$checksum" "$mirrors"; then
    log_msg "Downloaded curated LoRA $filename"
    return 0
  fi

  log_msg "Failed to download curated LoRA $filename"
  return 1
}

install_curated_loras_by_name() {
  local names_raw="$1"
  local download_success=false

  while IFS= read -r name; do
    [ -z "$name" ] && continue
    local item
    item=$(jq -c --arg name "$name" '.items[] | select(.name == $name)' "$LORA_MANIFEST")
    if [ -z "$item" ]; then
      log_msg "No curated LoRA named $name found in manifest"
      continue
    fi

    if download_manifest_lora "$item"; then
      download_success=true
    fi
  done <<< "$names_raw"

  $download_success && return 0
  return 1
}

prompt_lora_source() {
  local default_source="curated"
  if command -v yad >/dev/null 2>&1; then
    local choice
    choice=$(yad --list --radiolist --title="Choose LoRA Source" --width=450 --height=250 \
      --column="Select":R --column="Source" TRUE "Curated Manifest" FALSE "CivitAI Browser")
    choice=$(echo "$choice" | cut -d '|' -f2)
    case "$choice" in
      "CivitAI Browser") echo "civitai"; return ;;
      *) echo "curated"; return ;;
    esac
  fi
  echo "$default_source"
}

choose_curated_loras() {
  if [ ! -f "$LORA_MANIFEST" ]; then
    notify error "Manifest missing" "Curated LoRA manifest not found at $LORA_MANIFEST"
    return 1
  fi

  local entries=()
  declare -A ENTRY_DATA

  while IFS= read -r item; do
    local name version size license tags notes filename url checksum
    name=$(echo "$item" | jq -r '.name')
    version=$(echo "$item" | jq -r '.version')
    size=$(echo "$item" | jq -r '.size_bytes // 0')
    license=$(echo "$item" | jq -r '.license // "Unknown"')
    tags=$(echo "$item" | jq -r '.tags | join(", ")')
    notes=$(echo "$item" | jq -r '.notes // ""')
    filename=$(echo "$item" | jq -r '.filename')
    url=$(echo "$item" | jq -r '.url')
    checksum=$(echo "$item" | jq -r '.checksum')
    size_human=$(human_size "$size")

    entries+=(FALSE "$name" "$version" "$size_human" "$license" "$tags" "$notes")
    ENTRY_DATA["$name"]="$item"
  done < <(jq -c '.items[]' "$LORA_MANIFEST")

  if [ ${#entries[@]} -eq 0 ]; then
    notify error "Manifest empty" "No LoRAs found in $LORA_MANIFEST"
    return 1
  fi

  local selection
  selection=$(yad --list --checklist --separator="\n" --width=1000 --height=500 --title="Curated LoRAs" \
    --column="Select":CHK --column="Name" --column="Version" --column="Size" --column="License" --column="Tags" --column="Notes" \
    "${entries[@]}")

  if [ -z "$selection" ]; then
    log_msg "No curated LoRAs selected"
    return 1
  fi

  local download_success=false
  while IFS='|' read -r name _rest; do
    [ -z "$name" ] && continue
    local item="${ENTRY_DATA[$name]}"
    if download_manifest_lora "$item"; then
      download_success=true
    fi
  done <<< "$selection"

  $download_success && return 0
  return 1
}

require_commands yad jq curl sha256sum
ensure_downloader
offer_backup

SOURCE="${LORA_SOURCE:-$(prompt_lora_source)}"
SOURCE=$(echo "$SOURCE" | tr '[:upper:]' '[:lower:]')

if [ "$FORCE_CURATED_SELECTION" -eq 1 ]; then
  SOURCE="curated"
fi

if [ "$SOURCE" = "curated" ]; then
  if [ "$FORCE_CURATED_SELECTION" -eq 1 ]; then
    if install_curated_loras_by_name "$(echo "$CURATED_LORA_NAMES" | tr ',' '\n')"; then
      config_set "state.loras_installed" "true"
      echo "$(date): Curated LoRA download completed." >> "$LOG_FILE"
      notify info "LoRA Download Complete" "✅ Selected curated LoRAs downloaded to $INSTALL_DIR"
      exit 0
    else
      log_msg "Curated LoRA selection failed; reverting to CivitAI browser"
      SOURCE="civitai"
    fi
  elif ! command -v yad >/dev/null 2>&1; then
    echo "Curated manifest browsing requires YAD. Falling back to live CivitAI browser." >&2
    SOURCE="civitai"
  elif choose_curated_loras; then
    config_set "state.loras_installed" "true"
    echo "$(date): Curated LoRA download completed." >> "$LOG_FILE"
    notify info "LoRA Download Complete" "✅ Selected curated LoRAs downloaded to $INSTALL_DIR"
    exit 0
  else
    log_msg "Curated LoRA workflow failed; reverting to CivitAI browser"
    SOURCE="civitai"
  fi
fi

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
  if ! download_with_retries "$URL" "$DEST" "$CHECKSUM" ""; then
    echo "$(date): Download failed for $OUTNAME.$EXT" >> "$LOG_FILE"
    continue
  fi
  echo "$(date): Downloaded $OUTNAME.$EXT" >> "$LOG_FILE"
done

# Update config
config_set "state.loras_installed" "true"

if [[ -x "$SCRIPT_DIR/artifact_manager.sh" ]]; then
  HEADLESS=1 bash "$SCRIPT_DIR/artifact_manager.sh" --scan --verify-links --rotate-logs
fi

echo "$(date): LoRA selection and download completed." >> "$LOG_FILE"
notify info "LoRA Download Complete" "✅ Selected LoRAs downloaded to $INSTALL_DIR"
