#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$HOME/.config/aihub/install.log"

BACKUP_DIR="$HOME/.config/aihub/backups"
BACKUP_FILE=""
LOCAL_HEAD=""
REMOTE_HEAD=""

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

safe_exit() {
  log_msg "$1"
  notify_error "$1"
  exit 1
}

create_backup() {
  mkdir -p "$BACKUP_DIR" || safe_exit "❌ Unable to create backup directory at $BACKUP_DIR."
  local timestamp backup_path
  timestamp=$(date +%Y%m%d-%H%M%S)
  backup_path="$BACKUP_DIR/aihub-installer-$timestamp.tar.gz"

  log_msg "Creating backup at $backup_path"
  if git -C "$INSTALL_DIR" rev-parse HEAD >/dev/null 2>&1; then
    LOCAL_HEAD=$(git -C "$INSTALL_DIR" rev-parse HEAD 2>/dev/null)
  fi

  if git -C "$INSTALL_DIR" archive --format=tar.gz -o "$backup_path" HEAD >/dev/null 2>&1; then
    BACKUP_FILE="$backup_path"
    log_msg "Backup created successfully: $BACKUP_FILE"
    notify_info "📦 Backup created: $BACKUP_FILE\nRestore with: tar -xzf \"$BACKUP_FILE\" -C \"$INSTALL_DIR\""
  else
    safe_exit "❌ Failed to create a backup of the current installer."
  fi
}

restore_from_backup() {
  if [[ -n "$LOCAL_HEAD" ]]; then
    log_msg "Restoring git state to $LOCAL_HEAD"
    git -C "$INSTALL_DIR" reset --hard "$LOCAL_HEAD" >> "$LOG_FILE" 2>&1 || log_msg "Git reset to $LOCAL_HEAD failed; manual check required."
  fi

  if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
    log_msg "Restoring files from $BACKUP_FILE"
    tar -xzf "$BACKUP_FILE" -C "$INSTALL_DIR" >> "$LOG_FILE" 2>&1 || log_msg "Failed to restore files from $BACKUP_FILE"
  fi
}

fetch_remote_head() {
  REMOTE_HEAD=$(git -C "$INSTALL_DIR" ls-remote origin HEAD 2>>"$LOG_FILE" | awk 'NR==1 {print $1}')
  if [[ -z "$REMOTE_HEAD" ]]; then
    safe_exit "❌ Unable to determine remote update checksum (git ls-remote failed)."
  fi
  log_msg "Remote HEAD checksum: $REMOTE_HEAD"
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

UPDATE_PROMPT_TEXT=$'Proceed with updating the AI Installer?\nA backup will be created for rollback if validation fails.'

prompt_continue_cli() {
  printf "%b\n" "$UPDATE_PROMPT_TEXT"
  read -r -p "Continue? [y/N]: " response
  [[ "$response" =~ ^[Yy]$ ]]
}

prompt_continue_gui() {
  local output
  output=$(yad --question --title="Confirm Update" --text="$UPDATE_PROMPT_TEXT" --button=gtk-yes:0 --button=gtk-no:1 2>&1)
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

log_msg "Starting self-update process in $INSTALL_DIR"

fetch_remote_head

if git -C "$INSTALL_DIR" rev-parse HEAD >/dev/null 2>&1; then
  LOCAL_HEAD=$(git -C "$INSTALL_DIR" rev-parse HEAD 2>/dev/null)
  log_msg "Current local checksum: $LOCAL_HEAD"
fi

notify_info "🔄 Checking for updates from GitHub...\nRemote checksum: $REMOTE_HEAD"

if ! prompt_continue; then
  notify_info "Update canceled by user."
  log_msg "User canceled update."
  exit 0
fi

create_backup

notify_info "⬇️ Pulling latest changes..."

if git -C "$INSTALL_DIR" pull >> "$LOG_FILE" 2>&1; then
  UPDATED_HEAD=$(git -C "$INSTALL_DIR" rev-parse HEAD 2>/dev/null)
  log_msg "Updated checksum after pull: $UPDATED_HEAD"

  if [[ -n "$REMOTE_HEAD" && "$UPDATED_HEAD" != "$REMOTE_HEAD" ]]; then
    notify_error $'❌ Update checksum validation failed.\nThe downloaded update does not match the expected commit. Rolling back to the previous version.'
    restore_from_backup
    exit 1
  fi

  notify_info "✅ AI Installer has been updated (checksum: $UPDATED_HEAD). Relaunching..."
  exec bash "$INSTALL_DIR/aihub_menu.sh"
else
  notify_error $'❌ Git pull failed.\nRestoring previous version from backup. Check your internet connection or repository state.'
  restore_from_backup
  exit 1
fi
