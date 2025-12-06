#!/bin/bash
# Shared logging helpers for AI Hub scripts

CONFIG_ROOT="${CONFIG_ROOT:-$HOME/.config/aihub}"
LOG_FILE="${LOG_FILE:-$CONFIG_ROOT/install.log}"
METRICS_ROOT="${METRICS_ROOT:-$CONFIG_ROOT/metrics}"
METRICS_START_ROOT="${METRICS_START_ROOT:-$METRICS_ROOT/starts}"

mkdir -p "$CONFIG_ROOT" "$METRICS_ROOT" "$METRICS_START_ROOT"
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
