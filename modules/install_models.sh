#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
LOG_FILE="$HOME/.config/aihub/install.log"
MODEL_DIR="$HOME/AI/models"

mkdir -p "$(dirname "$CONFIG_FILE")" "$(dirname "$LOG_FILE")" "$MODEL_DIR"
touch "$CONFIG_FILE" "$LOG_FILE"

[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

log_msg() {
  echo "$(date): $1" >> "$LOG_FILE"
}

download_with_retries() {
  local url="$1" dest="$2" header="$3"
  log_msg "Starting download: $dest from $url"

  if command -v aria2c >/dev/null 2>&1; then
    local args=(--continue=true --max-tries=5 --retry-wait=5 --dir="$(dirname "$dest")" --out="$(basename "$dest")")
    [ -n "$header" ] && args+=(--header="$header")
    if aria2c "${args[@]}" "$url"; then
      return 0
    fi
  else
    local args=(--continue --show-progress --tries=5 --waitretry=5 -O "$dest")
    [ -n "$header" ] && args+=(--header="$header")
    if wget "${args[@]}" "$url"; then
      return 0
    fi
  fi

  return 1
}

set_config_value() {
  local key="$1" value="$2"
  if grep -q "^${key}=" "$CONFIG_FILE"; then
    sed -i "s/^${key}=.*/${key}=${value}/" "$CONFIG_FILE"
  else
    echo "${key}=${value}" >> "$CONFIG_FILE"
  fi
}

prompt_model_source() {
  local default_source="huggingface"
  if command -v yad >/dev/null 2>&1; then
    local choice
    choice=$(yad --list --radiolist --title="Choose Model Source" --width=400 --height=200 \
      --column="Select":R --column="Source" TRUE "Hugging Face" FALSE "CivitAI")
    choice=$(echo "$choice" | cut -d '|' -f2)
    if [ "$choice" = "CivitAI" ]; then
      echo "civitai"
      return
    fi
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
  print("\t".join([name, model_type, size, nsfw, file_format, url, filename]))
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
    --column="Name" --column="Type" --column="Size" --column="NSFW" --column="Format" --column="URL" --column="Filename")

  if [ -z "$selection" ]; then
    log_msg "CivitAI selection canceled"
    return 1
  fi

  local download_success=false
  while IFS='|' read -r name type size nsfw format url filename; do
    [ -z "$url" ] && continue
    local dest="$MODEL_DIR/$filename"
    if download_with_retries "$url" "$dest" ""; then
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

download_huggingface_model() {
  local hf_token="$1"
  local dest="$MODEL_DIR/sd-v1-5.ckpt"
  local url="https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.ckpt?download=1"
  local header=""
  if [ -n "$hf_token" ]; then
    header="Authorization: Bearer $hf_token"
  fi

  log_msg "Downloading base model (SD1.5) from Hugging Face"
  if download_with_retries "$url" "$dest" "$header"; then
    return 0
  fi

  return 1
}

SOURCE="${MODEL_SOURCE:-$(prompt_model_source)}"
SOURCE=$(echo "$SOURCE" | tr '[:upper:]' '[:lower:]')

case "$SOURCE" in
  civitai|huggingface)
    ;;
  *)
    SOURCE="huggingface"
    ;;
esac

log_msg "Selected model source: $SOURCE"

if [ "$SOURCE" = "civitai" ] && ! command -v yad >/dev/null 2>&1; then
  echo "CivitAI browsing requires YAD. Falling back to Hugging Face." >&2
  SOURCE="huggingface"
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
