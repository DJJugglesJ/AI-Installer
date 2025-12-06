#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/health_common.sh"

PORT="${SILLYTAVERN_PORT:-8000}"
MODEL_PATH="${SILLYTAVERN_CONFIG_PATH:-$HOME/AI/SillyTavern/config.json}"
BACKEND_LABEL="${gpu_mode:-Unknown}"

port_status=$(check_port_status "$PORT")
if [ -f "$MODEL_PATH" ]; then
  model_status="present"
else
  model_status="missing"
fi

metrics_record_start "sillytavern"
metrics_write "sillytavern" "port_status=${port_status}" "model_status=${model_status}" "backend=${BACKEND_LABEL}"

summary=$(summarize_result "sillytavern" "$PORT" "$MODEL_PATH" "$BACKEND_LABEL" "$port_status" "$model_status")
log_event "info" app=sillytavern event=health_summary summary="$summary"

if [[ "$BACKEND_LABEL" == "" || "$BACKEND_LABEL" == "Unknown" ]]; then
  log_event "warn" app=sillytavern event=health_hint hint="$(remediation_hint backend)"
fi

if [[ "$port_status" != "open" ]]; then
  log_event "warn" app=sillytavern event=health_hint hint="$(remediation_hint port)"
fi

if [[ "$model_status" != "present" ]]; then
  log_event "warn" app=sillytavern event=health_hint hint="Ensure config.json exists and points to a reachable backend (oobabooga/KoboldAI)."
fi

if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  echo "$summary"
else
  yad --info --title="SillyTavern Health" --text="$summary" --center --width=500 --wrap 2>/dev/null || echo "$summary"
fi
