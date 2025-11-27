#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
LOG_FILE="$HOME/.config/aihub/install.log"
MODEL_DIR="$HOME/AI/models"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"
MODEL_MANIFEST="$MANIFEST_DIR/models.json"

mkdir -p "$(dirname "$CONFIG_FILE")" "$(dirname "$LOG_FILE")" "$MODEL_DIR"
touch "$CONFIG_FILE" "$LOG_FILE"

[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

notify() {
  local level="$1" title="$2" message="$3"
  if command -v yad >/dev/null 2>&1; then
    case "$level" in
      error) yad --error --title="$title" --text="$message" --width=400 ;;
      info) yad --info --title="$title" --text="$message" --width=400 ;;
      warning) yad --warning --title="$title" --text="$message" --width=400 ;;
    esac
  else
    echo "$title: $message" >&2
  fi
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
    notify error "Missing prerequisites" "The following commands are required before installing models:\n\n$joined"
    exit 1
  fi
}

ensure_downloader() {
  if command -v aria2c >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
    return 0
  fi
  notify error "Downloader missing" "Please install either aria2 or wget to continue."
  exit 1
}

log_msg() {
  echo "$(date): $1" >> "$LOG_FILE"
}

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
  [ -f "$MODEL_MANIFEST" ] && files_to_backup+=("$MODEL_MANIFEST")

  [ ${#files_to_backup[@]} -eq 0 ] && return

  if command -v yad >/dev/null 2>&1; then
    if yad --question --title="Backup files" --text="Create a backup of installer config and model manifest before changes?"; then
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

verify_checksum() {
  local file="$1" expected="$2"
  if [ -z "$expected" ] || [ "$expected" = "null" ]; then
    log_msg "Checksum not provided for $(basename "$file"); skipping verification"
    return 0
  fi
  local actual
  actual=$(sha256sum "$file" | awk '{print $1}')
  if [ "$actual" != "$expected" ]; then
    notify error "Checksum mismatch" "The downloaded file $(basename "$file") failed verification. Expected $expected but found $actual."
    log_msg "Checksum mismatch for $file (expected: $expected, got: $actual); removing corrupt download"
    rm -f "$file"
    return 1
  fi
  log_msg "Checksum verified for $(basename "$file")"
  return 0
}

download_with_retries() {
  local url="$1" dest="$2" header="$3" expected_checksum="$4"
  local attempt=1 max_attempts=3 backoff=5
  log_msg "Starting download: $dest from $url"

  while [ $attempt -le $max_attempts ]; do
    if [ $attempt -gt 1 ]; then
      notify info "Retrying download" "Attempt $attempt of $max_attempts for $(basename "$dest")"
      log_msg "Retry attempt $attempt for $dest"
      sleep $backoff
      backoff=$((backoff * 2))
    fi

    if command -v aria2c >/dev/null 2>&1; then
      local args=(--continue=true --max-tries=1 --retry-wait=3 --dir="$(dirname "$dest")" --out="$(basename "$dest")")
      [ -n "$header" ] && args+=(--header="$header")
      if aria2c "${args[@]}" "$url"; then
        if verify_checksum "$dest" "$expected_checksum"; then
          return 0
        fi
      fi
    elif command -v wget >/dev/null 2>&1; then
      local args=(--continue --show-progress --tries=1 --waitretry=3 -O "$dest")
      [ -n "$header" ] && args+=(--header="$header")
      if wget "${args[@]}" "$url"; then
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

require_commands jq python3 sha256sum
ensure_downloader
offer_backup

HF_SD15_SHA256="${huggingface_sha256:-}"

set_config_value() {
  local key="$1" value="$2"
  if grep -q "^${key}=" "$CONFIG_FILE"; then
    sed -i "s/^${key}=.*/${key}=${value}/" "$CONFIG_FILE"
  else
    echo "${key}=${value}" >> "$CONFIG_FILE"
  fi
}

prompt_model_source() {
  local default_source="curated"
  if command -v yad >/dev/null 2>&1; then
    local choice
    choice=$(yad --list --radiolist --title="Choose Model Source" --width=450 --height=250 \
      --column="Select":R --column="Source" TRUE "Curated Manifest" FALSE "Hugging Face" FALSE "CivitAI")
    choice=$(echo "$choice" | cut -d '|' -f2)
    case "$choice" in
      "Hugging Face") echo "huggingface"; return ;;
      "CivitAI") echo "civitai"; return ;;
      *) echo "curated"; return ;;
    esac
  fi
  echo "$default_source"
}

fetch_civitai_models() {
  python3 - <<'PY'
import json
import math
import sys
import urllib.request

API_URL = "https://civitai.com/api/v1/models?types=Checkpoint&sort=Highest%20Rated&limit=50"


def format_size(bytes_count: float) -> str:
  if not bytes_count:
    return "Unknown"
  units = ["B", "KB", "MB", "GB", "TB"]
  power = int(math.log(bytes_count, 1024)) if bytes_count > 0 else 0
  power = min(power, len(units) - 1)
  size = bytes_count / (1024 ** power)
  return f"{size:.2f} {units[power]}"


def choose_file(version: dict):
  files = version.get("files") or []
  preferred = [".safetensors", ".ckpt"]
  for ext in preferred:
    for file in files:
      name = file.get("name") or ""
      if name.endswith(ext) and file.get("downloadUrl"):
        return file
  for file in files:
    if file.get("downloadUrl"):
      return file
  return None


try:
  with urllib.request.urlopen(API_URL, timeout=20) as response:
    data = json.load(response)
except Exception as exc:  # noqa: BLE001
  print(f"ERROR: {exc}", file=sys.stderr)
  sys.exit(1)

items = data.get("items") or []

for item in items:
  versions = item.get("modelVersions") or []
  if not versions:
    continue
  version = versions[0]
  file = choose_file(version)
  if not file:
    continue

  name = item.get("name", "Unknown")
  model_type = item.get("type", "Checkpoint")
  size_kb = file.get("sizeKB") or 0
  size = format_size(size_kb * 1024)
  nsfw = "Yes" if item.get("nsfw") else "No"
  filename = file.get("name") or "download.bin"
  file_format = "safetensors" if filename.endswith(".safetensors") else "ckpt" if filename.endswith(".ckpt") else "other"
  url = file.get("downloadUrl")
  checksum = (file.get("hashes") or {}).get("SHA256") or ""
  print("\t".join([name, model_type, size, nsfw, file_format, url, filename, checksum]))
PY
}

download_civitai_models() {
  log_msg "Fetching CivitAI model list"
  local model_list
  if ! model_list=$(fetch_civitai_models); then
    log_msg "Failed to fetch models from CivitAI"
    if command -v yad >/dev/null 2>&1; then
      yad --error --title="CivitAI Error" --text="Unable to fetch models from CivitAI."
    else
      echo "Unable to fetch models from CivitAI." >&2
    fi
    return 1
  fi

  if [ -z "$model_list" ]; then
    log_msg "No models received from CivitAI"
    if command -v yad >/dev/null 2>&1; then
      yad --warning --title="CivitAI" --text="No models available to display."
    else
      echo "No models available from CivitAI." >&2
    fi
    return 1
  fi

  local selection
  selection=$(echo "$model_list" | yad --list --multiple --separator="\n" --width=900 --height=600 --title="CivitAI Checkpoint Browser" \
    --column="Name" --column="Type" --column="Size" --column="NSFW" --column="Format" --column="URL" --column="Filename" --column="SHA256")

  if [ -z "$selection" ]; then
    log_msg "CivitAI selection canceled"
    return 1
  fi

  local download_success=false
  while IFS='|' read -r name type size nsfw format url filename checksum; do
    [ -z "$url" ] && continue
    local dest="$MODEL_DIR/$filename"
    if download_with_retries "$url" "$dest" "" "$checksum"; then
      log_msg "Downloaded $filename from CivitAI"
      download_success=true
    else
      log_msg "Failed to download $filename from CivitAI"
    fi
  done <<< "$selection"

  if ! $download_success; then
    return 1
  fi

  return 0
}

choose_curated_model() {
  if [ ! -f "$MODEL_MANIFEST" ]; then
    log_msg "Model manifest not found at $MODEL_MANIFEST"
    return 1
  fi

  local entries=()
  declare -A ENTRY_DATA

  while IFS= read -r item; do
    local name version size checksum license tags notes filename url
    name=$(echo "$item" | jq -r '.name')
    version=$(echo "$item" | jq -r '.version')
    size=$(echo "$item" | jq -r '.size_bytes // 0')
    checksum=$(echo "$item" | jq -r '.checksum // ""')
    license=$(echo "$item" | jq -r '.license // "Unknown"')
    tags=$(echo "$item" | jq -r '.tags | join(", ")')
    notes=$(echo "$item" | jq -r '.notes // ""')
    filename=$(echo "$item" | jq -r '.filename')
    url=$(echo "$item" | jq -r '.url')
    size_human=$(human_size "$size")

    entries+=(FALSE "$name" "$version" "$size_human" "$license" "$tags" "$notes")
    ENTRY_DATA["$name"]="$item"
  done < <(jq -c '.items[]' "$MODEL_MANIFEST")

  if [ ${#entries[@]} -eq 0 ]; then
    notify error "Manifest empty" "No models found in $MODEL_MANIFEST"
    return 1
  fi

  local selection
  selection=$(yad --list --checklist --separator="\n" --width=1000 --height=500 --title="Curated Models" \
    --column="Select":CHK --column="Name" --column="Version" --column="Size" --column="License" --column="Tags" --column="Notes" \
    "${entries[@]}")

  if [ -z "$selection" ]; then
    log_msg "No curated models selected"
    return 1
  fi

  local download_success=false
  while IFS='|' read -r name _rest; do
    [ -z "$name" ] && continue
    local item="${ENTRY_DATA[$name]}"
    local url filename checksum size
    url=$(echo "$item" | jq -r '.url')
    filename=$(echo "$item" | jq -r '.filename')
    checksum=$(echo "$item" | jq -r '.checksum')
    size=$(echo "$item" | jq -r '.size_bytes // 0')
    if [ -z "$url" ] || [ -z "$filename" ]; then
      log_msg "Skipping $name due to missing URL or filename"
      continue
    fi
    notify info "Downloading $name" "Version: $(echo "$item" | jq -r '.version')\nSize: $(human_size "$size")\nLicense: $(echo "$item" | jq -r '.license')"
    local dest="$MODEL_DIR/$filename"
    if download_with_retries "$url" "$dest" "" "$checksum"; then
      log_msg "Downloaded curated model $filename"
      download_success=true
    else
      log_msg "Failed to download curated model $filename"
    fi
  done <<< "$selection"

  $download_success && return 0
  return 1
}

download_huggingface_model() {
  local hf_token="$1"
  local dest="$MODEL_DIR/sd-v1-5.ckpt"
  local url="https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.ckpt?download=1"
  local header=""
  if [ -n "$hf_token" ]; then
    header="Authorization: Bearer $hf_token"
  fi

  log_msg "Downloading base model (SD1.5) from Hugging Face"
  if download_with_retries "$url" "$dest" "$header" "$HF_SD15_SHA256"; then
    return 0
  fi

  return 1
}

SOURCE="${MODEL_SOURCE:-$(prompt_model_source)}"
SOURCE=$(echo "$SOURCE" | tr '[:upper:]' '[:lower:]')

case "$SOURCE" in
  civitai|huggingface|curated)
    ;;
  *)
    SOURCE="curated"
    ;;
esac

log_msg "Selected model source: $SOURCE"

if [ "$SOURCE" = "civitai" ] && ! command -v yad >/dev/null 2>&1; then
  echo "CivitAI browsing requires YAD. Falling back to Hugging Face." >&2
  SOURCE="huggingface"
fi

if [ "$SOURCE" = "curated" ]; then
  if ! command -v yad >/dev/null 2>&1; then
    echo "Curated manifest browsing requires YAD. Falling back to Hugging Face." >&2
    SOURCE="huggingface"
  elif ! choose_curated_model; then
    log_msg "Curated model selection failed or was canceled"
    SOURCE="huggingface"
  fi
fi

if [ "$SOURCE" = "huggingface" ]; then
  HF_TOKEN="${huggingface_token:-}"

  if [ -z "$HF_TOKEN" ]; then
    if command -v yad >/dev/null 2>&1; then
      TOKEN_INPUT=$(yad --form --width=500 --title="Hugging Face Access" --field="Hugging Face token (optional)::TXT" "$HF_TOKEN")
      HF_TOKEN=$(echo "$TOKEN_INPUT" | cut -d '|' -f1 | tr -d '\r\n')
    else
      read -rp "Enter Hugging Face token (leave blank for anonymous download): " HF_TOKEN
    fi
  fi

  HF_TOKEN=$(echo "$HF_TOKEN" | tr -d '\r\n')

  if [ -n "$HF_TOKEN" ]; then
    set_config_value "huggingface_token" "$HF_TOKEN"
  fi

  if command -v yad >/dev/null 2>&1; then
    yad --info --title="Downloading Model" --text="Fetching Stable Diffusion base model (SD1.5)..."
  fi

  if ! download_huggingface_model "$HF_TOKEN"; then
    log_msg "Model download failed from Hugging Face"
    if command -v yad >/dev/null 2>&1; then
      yad --error --title="Download Failed" --text="Unable to download the Stable Diffusion model.\nEnsure your Hugging Face token is valid or try again later."
    else
      echo "Download failed. Ensure your Hugging Face token is valid or try again later." >&2
    fi
    exit 1
  fi
else
  if ! download_civitai_models; then
    log_msg "CivitAI download workflow did not complete"
    exit 1
  fi
fi

set_config_value "models_installed" "true"

if command -v yad >/dev/null 2>&1; then
  yad --info --text="✅ Model installed and config updated." --title="Install Complete"
fi

log_msg "install_models.sh installation completed"
