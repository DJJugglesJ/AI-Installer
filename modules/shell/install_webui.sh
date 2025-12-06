#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
CONFIG_STATE_FILE="${CONFIG_STATE_FILE:-$HOME/.config/aihub/config.yaml}"
LOG_FILE="$HOME/.config/aihub/install.log"
INSTALL_DIR="$HOME/AI/WebUI"
LORA_SOURCE="$HOME/AI/LoRAs"
LORA_TARGET="$INSTALL_DIR/models/Lora"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config_service/config_helpers.sh"

CONFIG_ENV_FILE="$CONFIG_FILE" CONFIG_STATE_FILE="$CONFIG_STATE_FILE" config_load
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log_msg() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$LOG_FILE"
}

REPO_URL="https://github.com/AUTOMATIC1111/stable-diffusion-webui.git"

if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  log_msg "Headless mode: proceeding with WebUI installation without prompts."
else
  yad --question --title="Install WebUI" --text="This will install the AUTOMATIC1111 Stable Diffusion WebUI to:\n$INSTALL_DIR\n\nProceed?" --button="Yes:0" --button="Cancel:1"
  if [ $? -ne 0 ]; then
    echo "$(date): User canceled WebUI installation." >> "$LOG_FILE"
    exit 1
  fi
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
if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  log_msg "Headless mode: installing WebUI requirements."
else
  yad --info --title="Installing Requirements" --text="Installing required Python dependencies..."
fi
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
config_set "state.webui_installed" "true"

if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  log_msg "WebUI installed and LoRA link created."
else
  yad --info --text="✅ WebUI installed and LoRA link created." --title="Install Complete"
fi
