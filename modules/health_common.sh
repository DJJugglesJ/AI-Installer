#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"
CONFIG_FILE="${CONFIG_FILE:-$HOME/.config/aihub/installer.conf}"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

check_port_status() {
  local port="$1"
  local host="${2:-127.0.0.1}"
  if command -v nc >/dev/null 2>&1; then
    if nc -z -w 2 "$host" "$port" >/dev/null 2>&1; then
      echo "open"
      return 0
    fi
  fi

  if command -v curl >/dev/null 2>&1; then
    if curl -s --max-time 2 "http://${host}:${port}" >/dev/null 2>&1; then
      echo "open"
      return 0
    fi
  fi

  echo "closed"
  return 1
}

check_model_folder() {
  local path="$1"
  if [ ! -d "$path" ]; then
    echo "missing"
    return 1
  fi
  if find -L "$path" -maxdepth 1 -type f | grep -q .; then
    echo "present"
    return 0
  fi
  echo "empty"
  return 2
}

summarize_result() {
  local app="$1"
  local port="$2"
  local model_path="$3"
  local backend_label="$4"
  local port_status="$5"
  local model_status="$6"

  local summary
  summary="${app}: backend=${backend_label}; port ${port} is ${port_status}; models=${model_status} (${model_path})"
  echo "$summary"
}

remediation_hint() {
  local kind="$1"
  case "$kind" in
    port)
      echo "Verify the service is running and not blocked by a firewall."
      ;;
    models)
      echo "Download or symlink at least one model into the expected directory."
      ;;
    backend)
      echo "Set gpu_mode via install.sh or config to match your hardware."
      ;;
    *)
      echo "Review logs for details."
      ;;
  esac
}
