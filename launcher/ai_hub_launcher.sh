#!/bin/bash

# AI Hub launcher status panel
# - Purpose: assemble an at-a-glance status report for installed apps and share it via clipboard-friendly dialog.
# - Assumptions: installer.conf and config.yaml reflect recent installs and YAD is available for UI rendering.
# - Side effects: reads recent log tail and may interact with clipboard utilities when requested.

CONFIG_FILE="$HOME/.config/aihub/installer.conf"
CONFIG_STATE_FILE="${CONFIG_STATE_FILE:-$HOME/.config/aihub/config.yaml}"
LOG_FILE="$HOME/.config/aihub/install.log"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../modules/config_service/config_helpers.sh"

CONFIG_ENV_FILE="$CONFIG_FILE" CONFIG_STATE_FILE="$CONFIG_STATE_FILE" config_load
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Use best-effort clipboard helpers so the dialog can export without assuming a desktop environment.
copy_to_clipboard() {
  local payload="$1"

  if command -v xclip >/dev/null 2>&1; then
    printf "%s" "$payload" | xclip -selection clipboard
    return 0
  fi

  if command -v wl-copy >/dev/null 2>&1; then
    printf "%s" "$payload" | wl-copy
    return 0
  fi

  if command -v pbcopy >/dev/null 2>&1; then
    printf "%s" "$payload" | pbcopy
    return 0
  fi

  return 1
}

status_line() {
  local label="$1" key="$2"
  local value="${!key:-}" status="Not installed"

  case "${value,,}" in
    "true"|"1"|"yes")
      status="Installed"
      ;;
    "")
      status="Not installed"
      ;;
    *)
      status="Not installed (${value})"
      ;;
  esac

  printf "- %s: %s\n" "$label" "$status"
}

collect_report() {
  local gpu_label
  gpu_label="${gpu_mode:-Unknown}"

  # Flatten install booleans into human-readable status lines for the dialog body.
  local statuses
  statuses=$(cat <<EOF
$(status_line "Stable Diffusion WebUI" "webui_installed")
$(status_line "KoboldAI" "kobold_installed")
$(status_line "SillyTavern" "sillytavern_installed")
$(status_line "LoRA Library" "loras_installed")
$(status_line "Model Downloads" "models_installed")
EOF
)

  local config_dump
  if [ -s "$CONFIG_FILE" ]; then
    config_dump=$(sed '/^\s*#/d;/^\s*$/d' "$CONFIG_FILE")
  else
    config_dump="<no config values recorded>"
  fi

  local log_tail
  log_tail=$(tail -n 50 "$LOG_FILE")

  cat <<EOF
AI Hub Installer Status
=======================

GPU mode: $gpu_label

Install statuses:
$statuses
Config values:
$config_dump

Recent log entries (tail -n 50):
$log_tail
EOF
}

show_dialog() {
  local report="$1"

  while true; do
    yad --width=800 --height=600 --center --title="AI Hub Status" \
      --text-info --editable --wrap --fontname="Monospace 10" \
      --button="Copy to Clipboard!gtk-copy:2" --button="Close!gtk-close:0" <<<"$report"

    local exit_code=$?

    case $exit_code in
      2)
        if copy_to_clipboard "$report"; then
          yad --info --title="Copied" --text="Status report copied to clipboard." --width=300 --center
        else
          yad --warning --title="Copy unavailable" --text="No clipboard utility found (xclip, wl-copy, or pbcopy)." --width=350 --center
        fi
        ;;
      *)
        break
        ;;
    esac
  done
}

report_content=$(collect_report)
show_dialog "$report_content"
