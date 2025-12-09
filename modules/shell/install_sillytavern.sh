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

APP_NAME="SillyTavern"
SILLY_DIR="$HOME/AI/${APP_NAME}"

mkdir -p "$HOME/AI"

if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  log_msg "[headless] Preparing ${APP_NAME} install/update..."
else
  yad --info --title="Installing ${APP_NAME}" --text="Preparing ${APP_NAME} install/update...\nAttempts and errors will be logged to $LOG_FILE."
  log_msg "Preparing ${APP_NAME} install/update..."
fi

if [[ -d "$SILLY_DIR" ]]; then
  log_msg "Found existing ${APP_NAME} at ${SILLY_DIR}, pulling latest changes..."
  if run_with_retry "Update ${APP_NAME}" git -C "$SILLY_DIR" pull >> "$LOG_FILE" 2>&1; then
    ACTION_RESULT="updated"
    ACTION_STATUS="success"
  else
    ACTION_RESULT="update failed"
    ACTION_STATUS="failure"
  fi
else
  log_msg "Cloning ${APP_NAME} into ${SILLY_DIR}..."
  if run_with_retry "Clone ${APP_NAME}" git clone https://github.com/SillyTavern/SillyTavern "$SILLY_DIR" >> "$LOG_FILE" 2>&1; then
    ACTION_RESULT="installed"
    ACTION_STATUS="success"
  else
    ACTION_RESULT="install failed"
    ACTION_STATUS="failure"
  fi
fi

if [[ "$ACTION_STATUS" == "success" ]]; then
  config_set "state.sillytavern_installed" "true"
fi

if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  if [[ "$ACTION_STATUS" == "success" ]]; then
    log_msg "[headless] ${APP_NAME} ${ACTION_RESULT} and config updated."
  else
    log_error "[headless] ${APP_NAME} ${ACTION_RESULT}. Check logs for details."
  fi
else
  if [[ "$ACTION_STATUS" == "success" ]]; then
    yad --info --text="✅ ${APP_NAME} ${ACTION_RESULT} and config updated." --title="Install Complete"
  else
    yad --error --text="❌ ${APP_NAME} ${ACTION_RESULT}. Check logs for details." --title="Install Failed"
  fi
  log_msg "install_sillytavern.sh ${ACTION_RESULT}."
fi
