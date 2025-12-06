#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"

HEALTH_LINES=()
HEALTH_LINES+=("$(HEADLESS=1 "$SCRIPT_DIR/health_webui.sh")")
HEALTH_LINES+=("$(HEADLESS=1 "$SCRIPT_DIR/health_kobold.sh")")
HEALTH_LINES+=("$(HEADLESS=1 "$SCRIPT_DIR/health_sillytavern.sh")")

SUMMARY=$(printf '%s\n' "${HEALTH_LINES[@]}")

log_event "info" app=aihub event=health_summary message="Launcher health overview generated" detail="$SUMMARY"

if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  echo "$SUMMARY"
else
  yad --info --title="AI Hub Health Summary" --text="$SUMMARY" --center --width=600 --wrap 2>/dev/null || echo "$SUMMARY"
fi
