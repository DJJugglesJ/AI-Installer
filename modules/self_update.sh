#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$HOME/.config/aihub/install.log"

mkdir -p "$(dirname "$LOG_FILE")"

HEADLESS_MODE=false

if [[ "$1" == "--headless" || "$HEADLESS_UPDATE" == "1" ]]; then
  HEADLESS_MODE=true
fi

if ! command -v yad >/dev/null 2>&1; then
  HEADLESS_MODE=true
  echo "YAD not found. Falling back to CLI mode." >> "$LOG_FILE"
fi

if [[ -z "$DISPLAY" && "$HEADLESS_MODE" = false ]]; then
  HEADLESS_MODE=true
  echo "DISPLAY not set. Falling back to CLI mode." >> "$LOG_FILE"
fi

log_msg() {
  echo "$(date): $1" >> "$LOG_FILE"
}

if $HEADLESS_MODE; then
  log_msg "Headless mode enabled; using CLI prompts."
fi

notify_info() {
  log_msg "$1"
  if $HEADLESS_MODE; then
    echo "INFO: $1"
  else
    yad --info --title="Updating Installer" --text="$1"
  fi
}

notify_error() {
  log_msg "$1"
  if $HEADLESS_MODE; then
    echo "ERROR: $1" >&2
  else
    yad --error --title="Update Failed" --text="$1"
  fi
}

prompt_continue_cli() {
  read -r -p "Proceed with updating the AI Installer? [y/N]: " response
  [[ "$response" =~ ^[Yy]$ ]]
}

prompt_continue_gui() {
  local output
  output=$(yad --question --title="Confirm Update" --text="Proceed with updating the AI Installer?" --button=gtk-yes:0 --button=gtk-no:1 2>&1)
  local status=$?

  case $status in
    0)
      return 0
      ;;
    1)
      return 1
      ;;
    *)
      log_msg "YAD prompt failed with exit $status: $output"
      return 2
      ;;
  esac
}

prompt_continue() {
  if $HEADLESS_MODE; then
    prompt_continue_cli
    return $?
  fi

  prompt_continue_gui
  local status=$?

  if [ $status -eq 2 ]; then
    HEADLESS_MODE=true
    notify_info "GUI prompt unavailable; falling back to CLI prompts."
    prompt_continue_cli
    return $?
  fi

  return $status
}

if [ ! -d "$INSTALL_DIR/.git" ]; then
  notify_error $'❌ This installation wasn\'t cloned from GitHub.\nSelf-updater is unavailable.'
  exit 1
fi

cd "$INSTALL_DIR" || {
  notify_error "❌ Failed to change directory to installation path at $INSTALL_DIR."
  exit 1
}

notify_info "🔄 Checking for updates from GitHub..."

if ! prompt_continue; then
  notify_info "Update canceled by user."
  exit 0
fi

if git pull; then
  notify_info "✅ AI Installer has been updated. Relaunching..."
  exec bash "$INSTALL_DIR/aihub_menu.sh"
else
  notify_error $'❌ Git pull failed.\nCheck your internet connection or repository state.'
  exit 1
fi
