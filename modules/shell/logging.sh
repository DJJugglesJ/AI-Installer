#!/bin/bash
set -euo pipefail
# Shared logging helpers for AI Hub scripts

CONFIG_ROOT="${AIHUB_CONFIG_DIR:-${CONFIG_ROOT:-$HOME/.config/aihub}}"
LOG_DIR="${AIHUB_LOG_DIR:-$CONFIG_ROOT/logs}"
LOG_DATE="${AIHUB_LOG_DATE:-$(date -u '+%Y%m%d')}"
LOG_FILE="${AIHUB_LOG_PATH:-$LOG_DIR/install-${LOG_DATE}.log}"
METRICS_ROOT="${METRICS_ROOT:-$CONFIG_ROOT/metrics}"
METRICS_START_ROOT="${METRICS_START_ROOT:-$METRICS_ROOT/starts}"

export AIHUB_LOG_DIR="$LOG_DIR"
export AIHUB_LOG_PATH="$LOG_FILE"
export AIHUB_LOG_DATE="$LOG_DATE"

mkdir -p "$CONFIG_ROOT" "$LOG_DIR" "$METRICS_ROOT" "$METRICS_START_ROOT"
touch "$LOG_FILE"

escape_json() {
  local text="$1"
  text="${text//\\/\\\\}"
  text="${text//\"/\\\"}"
  text="${text//$'\n'/ }"
  echo "$text"
}

log_event() {
  local level="$1"
  shift
  local ts
  ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  local json
  json="{\"ts\":\"${ts}\",\"level\":\"$(escape_json "$level")\""
  for pair in "$@"; do
    local key="${pair%%=*}"
    local value="${pair#*=}"
    json+="\",\"${key}\":\"$(escape_json "$value")\""
  done
  json+="}"
  echo "$json" | tee -a "$LOG_FILE" >/dev/null
}

log_msg() {
  local message="$1"
  log_event "info" message="$message"
}

log_error() {
  local message="$1"
  log_event "error" message="$message"
}

metrics_record_start() {
  local app="$1"
  local start_file="$METRICS_START_ROOT/${app}.start"
  if [ ! -f "$start_file" ]; then
    date -u '+%s' >"$start_file"
  fi
}

metrics_uptime() {
  local app="$1"
  local start_file="$METRICS_START_ROOT/${app}.start"
  if [ -f "$start_file" ]; then
    local start_ts
    start_ts=$(cat "$start_file")
    local now_ts
    now_ts=$(date -u '+%s')
    echo $((now_ts - start_ts))
  else
    echo ""
  fi
}

metrics_write() {
  local app="$1"
  shift
  local ts
  ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  local uptime
  uptime=$(metrics_uptime "$app")
  local json
  json="{\"app\":\"$(escape_json "$app")\",\"ts\":\"${ts}\""
  if [ -n "$uptime" ]; then
    json+="\",\"uptime_seconds\":${uptime}"
  fi
  for pair in "$@"; do
    local key="${pair%%=*}"
    local value="${pair#*=}"
    if [[ "$value" =~ ^[0-9]+$ ]]; then
      json+="\",\"${key}\":${value}"
    else
      json+="\",\"${key}\":\"$(escape_json "$value")\""
    fi
  done
  json+="}"
  echo "$json" >"$METRICS_ROOT/${app}.json"
}
