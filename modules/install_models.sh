#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
mkdir -p "$(dirname "$CONFIG_FILE")"
touch "$CONFIG_FILE"

mkdir -p ~/AI/models
yad --info --title="Downloading Model" --text="Fetching Stable Diffusion base model (SD1.5)..."

wget -q --show-progress -O ~/AI/models/sd-v1-5.ckpt https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.ckpt

if grep -q "^models_installed=" "$CONFIG_FILE"; then
  sed -i 's/^models_installed=.*/models_installed=true/' "$CONFIG_FILE"
else
  echo "models_installed=true" >> "$CONFIG_FILE"
fi

yad --info --text="✅ Model installed and config updated." --title="Install Complete"
