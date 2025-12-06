#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/health_common.sh"

PORT="${WEBUI_PORT:-7860}"
MODEL_PATH="${WEBUI_MODEL_PATH:-$HOME/AI/WebUI/models/Stable-diffusion}"
BACKEND_LABEL="${gpu_mode:-Unknown}"

port_status=$(check_port_status "$PORT")
model_status=$(check_model_folder "$MODEL_PATH")

metrics_record_start "webui"
metrics_write "webui" "port_status=${port_status}" "model_status=${model_status}" "backend=${BACKEND_LABEL}"

summary=$(summarize_result "webui" "$PORT" "$MODEL_PATH" "$BACKEND_LABEL" "$port_status" "$model_status")

log_event "info" app=webui event=health_summary summary="$summary"

if [[ "$BACKEND_LABEL" == "" || "$BACKEND_LABEL" == "Unknown" ]]; then
  log_event "warn" app=webui event=health_hint hint="$(remediation_hint backend)"
fi

if [[ "$port_status" != "open" ]]; then
  log_event "warn" app=webui event=health_hint hint="$(remediation_hint port)"
fi

if [[ "$model_status" != "present" ]]; then
  log_event "warn" app=webui event=health_hint hint="$(remediation_hint models)"
fi

if [[ "${HEADLESS:-0}" -eq 1 ]]; then
  echo "$summary"
else
  yad --info --title="Stable Diffusion WebUI Health" --text="$summary" --center --width=500 --wrap 2>/dev/null || echo "$summary"
fi
