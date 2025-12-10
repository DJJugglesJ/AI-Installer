#!/bin/bash
set -euo pipefail

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
CONFIG_STATE_FILE="${CONFIG_STATE_FILE:-$HOME/.config/aihub/config.yaml}"
LOG_FILE="$HOME/.config/aihub/install.log"
MODEL_DIR="$HOME/ai-hub/models"
WEBUI_SD_DIR="$HOME/AI/WebUI/models/Stable-diffusion"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../manifests"
MODEL_MANIFEST="$MANIFEST_DIR/models.json"
HEADLESS="${HEADLESS:-0}"
FORCE_CURATED_SELECTION=0
DOWNLOAD_LOG_FILE="$LOG_FILE"
DOWNLOAD_STATUS_FILE="${DOWNLOAD_STATUS_FILE:-}"

source "$SCRIPT_DIR/downloads/download_helpers.sh"

if [ -n "${CURATED_MODEL_NAMES:-}" ]; then
  FORCE_CURATED_SELECTION=1
fi

log_msg() {
  download_log "$1"
}

source "$SCRIPT_DIR/../config_service/config_helpers.sh"
CONFIG_ENV_FILE="$CONFIG_FILE" CONFIG_STATE_FILE="$CONFIG_STATE_FILE" config_load
mkdir -p "$(dirname "$LOG_FILE")" "$MODEL_DIR"
touch "$LOG_FILE"
log_msg "Model installer starting; logging to $LOG_FILE"

notify() {
  local level="$1" title="$2" message="$3"
  if [[ "$HEADLESS" -eq 1 ]]; then
    log_msg "[$level] $title — $message"
    return
  fi

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
    notify error "Missing prerequisites" "The following commands are required before installing models:\n\n$joined\n\nHelp: https://github.com/AI-Hub/AI-Hub#prerequisites"
    exit 1
  fi
}

ensure_downloader() {
  local has_aria=0 has_wget=0
  command -v aria2c >/dev/null 2>&1 && has_aria=1
  command -v wget >/dev/null 2>&1 && has_wget=1

  if [[ $has_aria -eq 0 && $has_wget -eq 0 ]]; then
    notify error "Downloader missing" "aria2c and wget are required for model downloads.\n\nInstall suggestions:\n  sudo apt-get install aria2 wget\n  brew install aria2 wget\n  choco install aria2 wget"
    log_msg "Preflight failed: aria2c and wget missing; aborting download flow"
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

  if [[ "$HEADLESS" -eq 1 ]]; then
    log_msg "[headless] Skipping backup prompt; continuing without creating backups"
    return
  fi

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

download_manifest_model() {
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
  local dest="$MODEL_DIR/$filename"
  if download_with_retries "$url" "$dest" "" "$checksum" "$mirrors"; then
    log_msg "Downloaded curated model $filename"
    return 0
  fi

  notify error "Download failed" "Unable to download $filename from available mirrors. Check connectivity or replace the URL."
  log_msg "Failed to download curated model $filename"
  return 1
}

install_curated_models_by_name() {
  local names_raw="$1"
  local download_success=false

  while IFS= read -r name; do
    [ -z "$name" ] && continue
    local item
    item=$(jq -c --arg name "$name" '.items[] | select(.name == $name)' "$MODEL_MANIFEST")
    if [ -z "$item" ]; then
      log_msg "No curated model named $name found in manifest"
      continue
    fi

    if download_manifest_model "$item"; then
      download_success=true
    fi
  done <<< "$names_raw"

  $download_success && return 0
  return 1
}

sync_webui_models() {
  mkdir -p "$WEBUI_SD_DIR"
  log_msg "Ensured WebUI Stable Diffusion directory exists at $WEBUI_SD_DIR"

  local model_files=()
  while IFS= read -r file; do
    model_files+=("$file")
  done < <(find "$MODEL_DIR" -maxdepth 1 -type f \( -name '*.ckpt' -o -name '*.safetensors' \))

  if [ ${#model_files[@]} -eq 0 ]; then
    log_msg "No checkpoint files found in $MODEL_DIR to link into WebUI directory"
    return
  fi

  for file in "${model_files[@]}"; do
    local filename link_path existing_target
    filename="$(basename "$file")"
    link_path="$WEBUI_SD_DIR/$filename"

    if [ -L "$link_path" ]; then
      existing_target=$(readlink -f "$link_path")
      if [ "$existing_target" = "$file" ]; then
        log_msg "Symlink already present for $filename; skipping"
        continue
      fi
      log_msg "Updating symlink for $filename to point to $file"
      ln -sf "$file" "$link_path"
      continue
    fi

    if [ -e "$link_path" ]; then
      log_msg "Existing file found at $link_path; leaving in place to avoid duplicates"
      continue
    fi

    ln -s "$file" "$link_path"
    log_msg "Linked $filename into WebUI Stable Diffusion directory"
  done
}

require_commands jq python3 sha256sum
ensure_downloader
offer_backup

HF_SD15_SHA256="${huggingface_sha256:-}"

set_config_value() {
  local key="$1" value="$2"
  config_set "$key" "$value"
}

prompt_model_source() {
  local default_source="curated"

  if [[ "$HEADLESS" -eq 1 ]]; then
    log_msg "[headless] Defaulting model source to Hugging Face"
    echo "huggingface"
    return
  fi

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
  if [[ "$HEADLESS" -eq 1 ]]; then
    log_msg "[headless] Skipping CivitAI flow because it requires interactive selection"
    return 1
  fi

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
    if download_with_retries "$url" "$dest" "" "$checksum" ""; then
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
  if [[ "$HEADLESS" -eq 1 ]]; then
    log_msg "[headless] Skipping curated manifest flow because it requires interactive selection"
    return 1
  fi

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
    if download_manifest_model "$item"; then
      download_success=true
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
  if download_with_retries "$url" "$dest" "$header" "$HF_SD15_SHA256" ""; then
    return 0
  fi

  return 1
}

SOURCE="${MODEL_SOURCE:-$(prompt_model_source)}"
SOURCE=$(echo "$SOURCE" | tr '[:upper:]' '[:lower:]')

if [ "$FORCE_CURATED_SELECTION" -eq 1 ]; then
  SOURCE="curated"
fi

if [[ "$HEADLESS" -eq 1 && "$FORCE_CURATED_SELECTION" -ne 1 ]]; then
  case "$SOURCE" in
    civitai|curated)
      log_msg "[headless] Forcing model source to Hugging Face to avoid interactive prompts"
      SOURCE="huggingface"
      ;;
  esac
fi

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
  if [ "$FORCE_CURATED_SELECTION" -eq 1 ]; then
    if install_curated_models_by_name "$(echo "$CURATED_MODEL_NAMES" | tr ',' '\n')"; then
      notify info "Model Download Complete" "✅ Selected curated models downloaded to $MODEL_DIR"
      exit 0
    else
      log_msg "Curated model selection failed; falling back to Hugging Face"
      SOURCE="huggingface"
    fi
  elif ! command -v yad >/dev/null 2>&1; then
    echo "Curated manifest browsing requires YAD. Falling back to Hugging Face." >&2
    SOURCE="huggingface"
  elif ! choose_curated_model; then
    log_msg "Curated model selection failed or was canceled"
    SOURCE="huggingface"
  fi
fi

if [ "$SOURCE" = "huggingface" ]; then
  HF_TOKEN="${huggingface_token:-${HUGGINGFACE_TOKEN:-}}"

  if [ -z "$HF_TOKEN" ] && [[ "$HEADLESS" -ne 1 ]]; then
    if command -v yad >/dev/null 2>&1; then
      TOKEN_INPUT=$(yad --form --width=500 --title="Hugging Face Access" --field="Hugging Face token (optional)::TXT" "$HF_TOKEN")
      HF_TOKEN=$(echo "$TOKEN_INPUT" | cut -d '|' -f1 | tr -d '\r\n')
    else
      read -rp "Enter Hugging Face token (leave blank for anonymous download): " HF_TOKEN
    fi
  fi

  HF_TOKEN=$(echo "$HF_TOKEN" | tr -d '\r\n')

  if [ -n "$HF_TOKEN" ]; then
    config_set "installer.huggingface_token" "$HF_TOKEN"
  elif [[ "$HEADLESS" -eq 1 ]]; then
    log_msg "[headless] Proceeding with anonymous Hugging Face download; set HUGGINGFACE_TOKEN or huggingface_token in config to use authentication"
  fi

  if command -v yad >/dev/null 2>&1 && [[ "$HEADLESS" -ne 1 ]]; then
    yad --info --title="Downloading Model" --text="Fetching Stable Diffusion base model (SD1.5)..."
  else
    log_msg "Starting base model download from Hugging Face"
  fi

  if ! download_huggingface_model "$HF_TOKEN"; then
    log_msg "Model download failed from Hugging Face"
    if command -v yad >/dev/null 2>&1 && [[ "$HEADLESS" -ne 1 ]]; then
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

sync_webui_models

config_set "state.models_installed" "true"

if [[ -x "$SCRIPT_DIR/artifact_manager.sh" ]]; then
  HEADLESS=1 bash "$SCRIPT_DIR/artifact_manager.sh" --scan --verify-links --rotate-logs
fi

if command -v yad >/dev/null 2>&1 && [[ "$HEADLESS" -ne 1 ]]; then
  yad --info --text="✅ Model installed and config updated." --title="Install Complete"
else
  log_msg "Model installed and config updated"
fi

log_msg "install_models.sh installation completed"
