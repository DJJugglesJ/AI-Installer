#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/health_common.sh"

PORT="${KOBOLD_PORT:-5001}"
MODEL_PATH="${KOBOLD_MODEL_PATH:-$HOME/AI/KoboldAI/models}"
BACKEND_LABEL="${gpu_mode:-Unknown}"

port_status=$(check_port_status "$PORT")
model_status=$(check_model_folder "$MODEL_PATH")

metrics_record_start "kobold"
metrics_write "kobold" "port_status=${port_status}" "model_status=${model_status}" "backend=${BACKEND_LABEL}"

summary=$(summarize_result "kobold" "$PORT" "$MODEL_PATH" "$BACKEND_LABEL" "$port_status" "$model_status")
log_event "info" app=kobold event=health_summary summary="$summary"

if [[ "$BACKEND_LABEL" == "" || "$BACKEND_LABEL" == "Unknown" ]]; then
  log_event "warn" app=kobold event=health_hint hint="$(remediation_hint backend)"
fi

if [[ "$port_status" != "open" ]]; then
  log_event "warn" app=kobold event=health_hint hint="$(remediation_hint port)"
fi

if [[ "$model_status" != "present" ]]; then
  log_event "warn" app=kobold event=health_hint hint="$(remediation_hint models)"
fi

if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  echo "$summary"
else
  yad --info --title="KoboldAI Health" --text="$summary" --center --width=500 --wrap 2>/dev/null || echo "$summary"
fi
