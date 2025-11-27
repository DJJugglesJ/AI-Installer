#!/bin/bash

# install.sh — AI Workstation Setup Launcher
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PATH="$SCRIPT_DIR"
MODULE_DIR="$INSTALL_PATH/modules"
CONFIG_FILE="$HOME/.config/aihub/installer.conf"
DESKTOP_ENTRY="$HOME/Desktop/AI-Workstation-Launcher.desktop"
LOG_FILE="$HOME/.config/aihub/install.log"

HEADLESS_MODE=false
INSTALL_TARGET=""
GPU_MODE_OVERRIDE=""

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --headless           Run without YAD prompts using config defaults.
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
      shift
      ;;
    --gpu)
      GPU_MODE_OVERRIDE="$2"
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
export GPU_MODE_OVERRIDE

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
    notify_prereq "The following tools are required before running the installer:\n\n$joined\n\nPlease install them with: sudo apt install ${missing[*]}"
    exit 1
  fi
}

# Ensure we have the basics to prompt and install dependencies before proceeding
require_commands bash dpkg sudo apt

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

if [[ "$HEADLESS" -eq 1 ]]; then
  log_msg "Running installer in headless mode."
fi

# ✅ Check for required dependencies
HEADLESS=$HEADLESS bash "$MODULE_DIR/check_dependencies.sh"

# 🔍 GPU detection
CONFIG_FILE="$CONFIG_FILE" HEADLESS=$HEADLESS GPU_MODE_OVERRIDE="$GPU_MODE_OVERRIDE" bash "$MODULE_DIR/detect_gpu.sh"

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
