#!/bin/bash

# install.sh — AI Workstation Setup Launcher
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PATH="$SCRIPT_DIR"
MODULE_DIR="$INSTALL_PATH/modules"
DEFAULT_CONFIG_FILE="$HOME/.config/aihub/installer.conf"
CONFIG_FILE="$DEFAULT_CONFIG_FILE"
CONFIG_STATE_FILE="$HOME/.config/aihub/config.yaml"
DESKTOP_ENTRY="$HOME/Desktop/AI-Workstation-Launcher.desktop"
LOG_FILE="$HOME/.config/aihub/install.log"

source "$MODULE_DIR/config_service/config_helpers.sh"

HEADLESS_MODE=false
INSTALL_TARGET=""
GPU_MODE_OVERRIDE=""
USER_CONFIG_FILE=""
CONFIG_OVERRIDES=()

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --headless           Run without YAD prompts using config defaults.
  --config <file>      Path to a JSON or env-style config file used in headless mode.
  --install <target>   Install a component directly (e.g. webui, kobold, sillytavern, loras, models).
  --gpu <mode>         Force GPU mode (nvidia|amd|intel|cpu) and skip GPU prompts.
  -h, --help           Show this help message.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --headless)
      HEADLESS_MODE=true
      ;;
    --install)
      INSTALL_TARGET="$2"
      CONFIG_OVERRIDES+=("--set" "installer.install_target=$2")
      shift
      ;;
    --gpu)
      GPU_MODE_OVERRIDE="$2"
      CONFIG_OVERRIDES+=("--set" "gpu.mode=$2")
      shift
      ;;
    --config)
      USER_CONFIG_FILE="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

export HEADLESS=$([[ "$HEADLESS_MODE" == true ]] && echo 1 || echo 0)

if [[ "$HEADLESS_MODE" == true && -n "$USER_CONFIG_FILE" ]]; then
  CONFIG_FILE="$USER_CONFIG_FILE"
fi

if ! CONFIG_ENV_FILE="$CONFIG_FILE" CONFIG_STATE_FILE="$CONFIG_STATE_FILE" config_load "${CONFIG_OVERRIDES[@]}"; then
  echo "[!] Failed to load configuration from $CONFIG_STATE_FILE" >&2
  exit 1
fi

notify_prereq() {
  local message="$1"
  if command -v yad >/dev/null 2>&1; then
    yad --error --title="Missing Prerequisite" --text="$message" --width=400
  else
    echo "[!] $message" >&2
  fi
}

require_commands() {
  local missing=()
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    local joined
    joined=$(IFS=$'\n'; echo "${missing[*]}")
    notify_prereq "The following tools are required before running the installer:\n\n$joined\n\nPlease install them using your system package manager (e.g., apt, dnf, or pacman)."
    exit 1
  fi
}

# Ensure we have the basics to prompt and install dependencies before proceeding
require_commands bash sudo

mkdir -p "$INSTALL_PATH"
mkdir -p "$(dirname "$CONFIG_FILE")"
mkdir -p "$(dirname "$DESKTOP_ENTRY")"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$CONFIG_FILE"
touch "$LOG_FILE"

log_msg() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$LOG_FILE"
}

strip_quotes() {
  local value="$1"
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"
  echo "$value"
}

normalize_bool() {
  local raw="$1"
  case "${raw,,}" in
    true|1|yes|y|on)
      echo "true"
      ;;
    *)
      echo "false"
      ;;
  esac
}

declare -A HEADLESS_CONFIG

parse_env_config() {
  local file="$1"
  while IFS='=' read -r raw_key raw_value; do
    [[ -z "$raw_key" || "$raw_key" =~ ^# ]] && continue
    local key value
    key="${raw_key// /}"
    value="${raw_value# }"
    value=$(strip_quotes "$value")
    HEADLESS_CONFIG[$key]="$value"
  done < "$file"
}

parse_json_config() {
  local file="$1"
  if ! command -v python3 >/dev/null 2>&1; then
    return 1
  fi
  local python_output
  python_output=$(python3 - <<'PY' "$file" 2>/dev/null)
import json, sys
path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)
for key, value in data.items():
    if isinstance(value, (dict, list)):
        continue
    print(f"{key}={value}")
PY
)

  if [[ $? -ne 0 || -z "$python_output" ]]; then
    return 1
  fi

  while IFS='=' read -r key value; do
    [[ -z "$key" ]] && continue
    value=$(strip_quotes "$value")
    HEADLESS_CONFIG[$key]="$value"
  done <<< "$python_output"
}

apply_headless_config() {
  [[ "$HEADLESS_MODE" != true ]] && return

  local source_file="$CONFIG_FILE"
  if [[ -n "$USER_CONFIG_FILE" ]]; then
    log_msg "Headless config supplied via --config: $source_file"
  else
    log_msg "Headless mode using default config path: $source_file"
  fi

  if [[ ! -f "$source_file" ]]; then
    log_msg "Headless config file not found; proceeding with built-in defaults."
  else
    if grep -q '{' "$source_file"; then
      if parse_json_config "$source_file"; then
        log_msg "Parsed JSON headless config successfully."
      else
        log_msg "Failed to parse JSON config; attempting env-style parsing instead."
        parse_env_config "$source_file"
      fi
    else
      parse_env_config "$source_file"
      log_msg "Parsed env-style headless config successfully."
    fi
  fi

  if [[ -z "$GPU_MODE_OVERRIDE" ]]; then
    if [[ -n "${HEADLESS_CONFIG[gpu_mode]}" ]]; then
      GPU_MODE_OVERRIDE="${HEADLESS_CONFIG[gpu_mode]}"
      log_msg "Headless config applied GPU mode: ${GPU_MODE_OVERRIDE}"
    else
      log_msg "Headless config missing gpu_mode; relying on auto-detection/default CPU fallback."
    fi
  else
    log_msg "GPU mode override provided via CLI; skipping config lookup."
  fi

  if [[ -z "$INSTALL_TARGET" ]]; then
    if [[ -n "${HEADLESS_CONFIG[install_target]}" ]]; then
      INSTALL_TARGET="${HEADLESS_CONFIG[install_target]}"
      log_msg "Headless config requested install target: ${INSTALL_TARGET}"
    elif [[ -n "${HEADLESS_CONFIG[install]}" ]]; then
      INSTALL_TARGET="${HEADLESS_CONFIG[install]}"
      log_msg "Headless config requested install target via 'install': ${INSTALL_TARGET}"
    else
      log_msg "Headless config did not specify an install target; launcher will be created without auto-install."
    fi
  else
    log_msg "Install target provided via CLI; skipping config lookup."
  fi

  local hf_token_config="${HEADLESS_CONFIG[huggingface_token]:-${HEADLESS_CONFIG[HUGGINGFACE_TOKEN]:-}}"
  if [[ -n "$hf_token_config" ]]; then
    if [[ -z "$HUGGINGFACE_TOKEN" ]]; then
      HUGGINGFACE_TOKEN="$hf_token_config"
      export HUGGINGFACE_TOKEN
      log_msg "Headless config supplied Hugging Face token for authenticated downloads."
    else
      log_msg "Hugging Face token already set via environment; keeping existing value."
    fi
    export huggingface_token="$hf_token_config"
  else
    log_msg "Headless config missing Hugging Face token; will use anonymous downloads when permitted."
  fi

  apply_boolean_flag() {
    local key="$1" description="$2"
    local raw_value="${HEADLESS_CONFIG[$key]:-}"
    [[ -z "$raw_value" ]] && return
    local normalized
    normalized=$(normalize_bool "$raw_value")
    config_set "$key" "$normalized"
    log_msg "Headless config set ${description} to ${normalized}."
  }

  apply_boolean_flag "enable_fp16" "FP16 preference"
  apply_boolean_flag "enable_xformers" "xFormers acceleration"
  apply_boolean_flag "enable_directml" "DirectML acceleration"
  apply_boolean_flag "enable_low_vram" "low VRAM mode"
}

if [[ "$HEADLESS" -eq 1 ]]; then
  log_msg "Running installer in headless mode."
fi

apply_headless_config
export GPU_MODE_OVERRIDE

# ✅ Cross-distro bootstrap for required packages
BOOTSTRAP_SCRIPT="$MODULE_DIR/bootstrap/bootstrap.sh"
if [[ -x "$BOOTSTRAP_SCRIPT" ]]; then
  log_msg "Running bootstrap to verify/install prerequisites."
  if ! HEADLESS=$HEADLESS bash "$BOOTSTRAP_SCRIPT" | tee -a "$LOG_FILE"; then
    echo "[!] Bootstrap failed; see $LOG_FILE for details." >&2
    exit 1
  fi
else
  log_msg "Bootstrap script missing; please ensure required packages are installed manually."
fi

# 🔍 GPU detection
CONFIG_FILE="$CONFIG_FILE" HEADLESS=$HEADLESS GPU_MODE_OVERRIDE="$GPU_MODE_OVERRIDE" bash "$MODULE_DIR/detect_gpu.sh"
DETECTED_GPU=$(grep '^detected_gpu=' "$CONFIG_FILE" | cut -d'=' -f2)
GPU_MODE_SELECTED=$(grep '^gpu_mode=' "$CONFIG_FILE" | cut -d'=' -f2)
GPU_SUMMARY_MSG="GPU summary: detected=${DETECTED_GPU:-unknown}, mode=${GPU_MODE_SELECTED:-unknown}"
echo "[✔] $GPU_SUMMARY_MSG"
log_msg "$GPU_SUMMARY_MSG"
if [[ "$HEADLESS" -eq 1 ]]; then
  log_msg "Headless GPU summary recorded for troubleshooting."
fi

# ✅ Create the unified desktop launcher
LAUNCH_CMD="$INSTALL_PATH/aihub_menu.sh"
cat > "$DESKTOP_ENTRY" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=AI Workstation Launcher
Comment=Launch the AI Workstation Menu
Exec=/bin/bash -lc '"$LAUNCH_CMD"'
Icon=utilities-terminal
Terminal=false
Categories=Utility;
EOF

chmod +x "$DESKTOP_ENTRY"
echo "[✔] Desktop launcher created at $DESKTOP_ENTRY"
log_msg "Installer launched and launcher created."

if [[ -n "$INSTALL_TARGET" ]]; then
  case "$INSTALL_TARGET" in
    webui)
      log_msg "Headless install requested: webui"
      HEADLESS=$HEADLESS bash "$MODULE_DIR/install_webui.sh"
      ;;
    kobold)
      log_msg "Headless install requested: kobold"
      HEADLESS=$HEADLESS bash "$MODULE_DIR/install_kobold.sh"
      ;;
    sillytavern)
      log_msg "Headless install requested: sillytavern"
      HEADLESS=$HEADLESS bash "$MODULE_DIR/install_sillytavern.sh"
      ;;
    loras)
      log_msg "Headless install requested: loras"
      HEADLESS=$HEADLESS bash "$MODULE_DIR/install_loras.sh"
      ;;
    models)
      log_msg "Headless install requested: models (Hugging Face)"
      HEADLESS=$HEADLESS bash "$MODULE_DIR/install_models.sh"
      ;;
    *)
      log_msg "Unknown install target: $INSTALL_TARGET"
      echo "Unknown install target: $INSTALL_TARGET" >&2
      ;;
  esac
fi
