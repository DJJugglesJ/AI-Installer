#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
mkdir -p "$(dirname "$CONFIG_FILE")"
touch "$CONFIG_FILE"
LOG_FILE="$HOME/.config/aihub/install.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

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
  if grep -q '^huggingface_token=' "$CONFIG_FILE"; then
    sed -i "s/^huggingface_token=.*/huggingface_token=$HF_TOKEN/" "$CONFIG_FILE"
  else
    echo "huggingface_token=$HF_TOKEN" >> "$CONFIG_FILE"
  fi
fi

mkdir -p "$HOME/AI/models"

if command -v yad >/dev/null 2>&1; then
  yad --info --title="Downloading Model" --text="Fetching Stable Diffusion base model (SD1.5)..."
fi

echo "$(date): Downloading base model (SD1.5)..." >> "$LOG_FILE"

DEST="$HOME/AI/models/sd-v1-5.ckpt"
DOWNLOAD_URL="https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.ckpt?download=1"

DOWNLOAD_SUCCESS=false

if command -v aria2c >/dev/null 2>&1; then
  ARIA_ARGS=(--continue=true --max-tries=5 --retry-wait=5 --dir="$(dirname "$DEST")" --out="$(basename "$DEST")")
  if [ -n "$HF_TOKEN" ]; then
    ARIA_ARGS+=(--header="Authorization: Bearer $HF_TOKEN")
  fi
  if aria2c "${ARIA_ARGS[@]}" "$DOWNLOAD_URL"; then
    DOWNLOAD_SUCCESS=true
  fi
else
  WGET_ARGS=(--continue --show-progress -O "$DEST")
  if [ -n "$HF_TOKEN" ]; then
    WGET_ARGS+=(--header="Authorization: Bearer $HF_TOKEN")
  fi
  if wget "${WGET_ARGS[@]}" "$DOWNLOAD_URL"; then
    DOWNLOAD_SUCCESS=true
  fi
fi

if ! $DOWNLOAD_SUCCESS; then
  echo "$(date): Model download failed from Hugging Face." >> "$LOG_FILE"
  if command -v yad >/dev/null 2>&1; then
    yad --error --title="Download Failed" --text="Unable to download the Stable Diffusion model.\nEnsure your Hugging Face token is valid or try again later."
  else
    echo "Download failed. Ensure your Hugging Face token is valid or try again later." >&2
  fi
  exit 1
fi

if grep -q "^models_installed=" "$CONFIG_FILE"; then
  sed -i 's/^models_installed=.*/models_installed=true/' "$CONFIG_FILE"
else
  echo "models_installed=true" >> "$CONFIG_FILE"
fi

if command -v yad >/dev/null 2>&1; then
  yad --info --text="✅ Model installed and config updated." --title="Install Complete"
fi

echo "$(date): install_models.sh installation completed." >> "$LOG_FILE"
