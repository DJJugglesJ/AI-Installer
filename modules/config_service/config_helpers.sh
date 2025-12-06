#!/bin/bash
# Shell helpers for AI Hub configuration service

CONFIG_ROOT="${CONFIG_ROOT:-$HOME/.config/aihub}"
CONFIG_STATE_FILE="${CONFIG_STATE_FILE:-$CONFIG_ROOT/config.yaml}"
CONFIG_ENV_FILE="${CONFIG_ENV_FILE:-$CONFIG_ROOT/installer.conf}"
CONFIG_SERVICE_SCRIPT="${CONFIG_SERVICE_SCRIPT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config_service.py}"
CONFIG_ENV_PREFIX="${CONFIG_ENV_PREFIX:-AIHUB_}"

ensure_config_paths() {
  mkdir -p "$CONFIG_ROOT"
}

config_export() {
  ensure_config_paths
  python3 "$CONFIG_SERVICE_SCRIPT" --config "$CONFIG_STATE_FILE" export --env-prefix "$CONFIG_ENV_PREFIX" --write-env "$CONFIG_ENV_FILE" "$@"
}

config_load() {
  local output
  output=$(config_export "$@") || return 1
  eval "$output"
}

config_save() {
  ensure_config_paths
  python3 "$CONFIG_SERVICE_SCRIPT" --config "$CONFIG_STATE_FILE" save --write-env "$CONFIG_ENV_FILE" "$@"
}

config_set() {
  local key="$1" value="$2"
  config_save --set "$key=$value" >/dev/null && config_load
}
