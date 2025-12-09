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

log_error() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] $message" | tee -a "$LOG_FILE" >&2
}

run_with_retry() {
  local description="$1"
  shift
  local attempt=0 max_attempts=3 last_exit=0

  while (( attempt < max_attempts )); do
    attempt=$((attempt + 1))
    log_msg "Starting ${description} (attempt ${attempt}/${max_attempts})"

    if "$@"; then
      log_msg "${description} succeeded on attempt ${attempt}/${max_attempts}"
      return 0
    fi

    last_exit=$?
    log_error "${description} failed with exit code ${last_exit} on attempt ${attempt}/${max_attempts}"

    if (( attempt >= max_attempts )); then
      break
    fi

    local retry=true
    if [[ "${HEADLESS:-0}" -eq 1 ]]; then
      log_msg "Headless mode: auto-retrying ${description} after failure"
      sleep 2
    elif command -v yad >/dev/null 2>&1; then
      yad --question --title="Retry ${description}?" --text="${description} did not complete (exit ${last_exit}).\nCheck $LOG_FILE for details. Retry now?" --button="Retry:0" --button="Skip:1"
      [[ $? -eq 0 ]] || retry=false
    else
      read -rp "${description} failed (exit ${last_exit}). Retry attempt $((attempt + 1))/${max_attempts}? [y/N]: " answer || true
      [[ "$answer" =~ ^[Yy]$ ]] || retry=false
    fi

    if ! $retry; then
      log_msg "User skipped retry for ${description} after attempt ${attempt}/${max_attempts}"
      break
    fi
  done

  log_error "${description} exhausted retries after ${attempt} attempt(s); last exit ${last_exit}"
  return 1
}

REPO_URL="https://github.com/AUTOMATIC1111/stable-diffusion-webui.git"

if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  log_msg "Headless mode: proceeding with WebUI installation without prompts."
else
  yad --question --title="Install WebUI" --text="This will install the AUTOMATIC1111 Stable Diffusion WebUI to:\n$INSTALL_DIR\n\nA log of each step is written to $LOG_FILE. Cancel to stop now, or continue to proceed." --button="Proceed:0" --button="Cancel:1"
  if [ $? -ne 0 ]; then
    log_msg "User canceled WebUI installation before cloning"
    exit 1
  fi
fi

mkdir -p "$INSTALL_DIR"

# Clone repo if not already there
if [ ! -d "$INSTALL_DIR/.git" ]; then
  if ! run_with_retry "Clone WebUI repository" git clone "$REPO_URL" "$INSTALL_DIR"; then
    log_error "Unable to clone WebUI repository to $INSTALL_DIR"
    exit 1
  fi
else
  if ! run_with_retry "Update WebUI repository" git -C "$INSTALL_DIR" pull; then
    log_error "Unable to update WebUI repository at $INSTALL_DIR"
    exit 1
  fi
fi

# Install python dependencies
cd "$INSTALL_DIR"
if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  log_msg "Headless mode: installing WebUI requirements."
else
  yad --info --title="Installing Requirements" --text="Installing required Python dependencies...\nThis may take a few minutes. Progress is logged to $LOG_FILE."
fi
if [ ! -d "venv" ]; then
  python3 -m venv venv
  echo "$(date): Created Python virtual environment." >> "$LOG_FILE"
fi

source venv/bin/activate
if ! run_with_retry "Upgrade pip in WebUI venv" pip install --upgrade pip; then
  exit 1
fi

if ! run_with_retry "Install WebUI Python dependencies" pip install -r requirements.txt; then
  exit 1
fi
log_msg "Installed WebUI Python dependencies."

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
