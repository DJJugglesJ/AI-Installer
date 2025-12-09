#!/bin/bash

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
CONFIG_STATE_FILE="${CONFIG_STATE_FILE:-$HOME/.config/aihub/config.yaml}"
LOG_FILE="$HOME/.config/aihub/install.log"

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

if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  log_msg "[headless] Installing KoboldAI..."
else
  yad --info --title="Installing KoboldAI" --text="Cloning KoboldAI...\nAttempts and errors will be logged to $LOG_FILE."
  log_msg "Cloning KoboldAI..."
fi

if ! run_with_retry "Clone KoboldAI" git clone https://github.com/KoboldAI/KoboldAI-Client ~/AI/KoboldAI; then
  log_error "KoboldAI clone failed; see $LOG_FILE for retry history"
  exit 1
fi

config_set "state.kobold_installed" "true"

if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  log_msg "[headless] KoboldAI installed and config updated."
else
  yad --info --text="✅ KoboldAI installed and config updated." --title="Install Complete"
  log_msg "install_kobold.sh installation completed."
fi
