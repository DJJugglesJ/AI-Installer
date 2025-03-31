#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
LOG_FILE="$HOME/.config/aihub/install.log"
INSTALL_DIR="$HOME/AI/WebUI"
LORA_SOURCE="$HOME/AI/LoRAs"
LORA_TARGET="$INSTALL_DIR/models/Lora"

mkdir -p "$(dirname "$CONFIG_FILE")"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$CONFIG_FILE"
touch "$LOG_FILE"

REPO_URL="https://github.com/AUTOMATIC1111/stable-diffusion-webui.git"

yad --question --title="Install WebUI" --text="This will install the AUTOMATIC1111 Stable Diffusion WebUI to:\n$INSTALL_DIR\n\nProceed?" --button="Yes:0" --button="Cancel:1"
if [ $? -ne 0 ]; then
  echo "$(date): User canceled WebUI installation." >> "$LOG_FILE"
  exit 1
fi

mkdir -p "$INSTALL_DIR"

# Clone repo if not already there
if [ ! -d "$INSTALL_DIR/.git" ]; then
  git clone "$REPO_URL" "$INSTALL_DIR"
  echo "$(date): Cloned WebUI repository." >> "$LOG_FILE"
else
  cd "$INSTALL_DIR" && git pull
  echo "$(date): Updated existing WebUI repo." >> "$LOG_FILE"
fi

# Install python dependencies
cd "$INSTALL_DIR"
yad --info --title="Installing Requirements" --text="Installing required Python dependencies..."
if [ ! -d "venv" ]; then
  python3 -m venv venv
  echo "$(date): Created Python virtual environment." >> "$LOG_FILE"
fi

source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
echo "$(date): Installed WebUI Python dependencies." >> "$LOG_FILE"

# Create or refresh symlink for LoRA models
mkdir -p "$LORA_SOURCE"
mkdir -p "$(dirname "$LORA_TARGET")"
rm -f "$LORA_TARGET"
ln -s "$LORA_SOURCE" "$LORA_TARGET"
echo "$(date): Linked LoRA directory ($LORA_SOURCE → $LORA_TARGET)" >> "$LOG_FILE"

# Update config
if grep -q "^webui_installed=" "$CONFIG_FILE"; then
  sed -i 's/^webui_installed=.*/webui_installed=true/' "$CONFIG_FILE"
else
  echo "webui_installed=true" >> "$CONFIG_FILE"
fi

yad --info --text="✅ WebUI installed and LoRA link created." --title="Install Complete"
