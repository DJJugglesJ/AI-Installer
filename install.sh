#!/bin/bash

# AI Hub installer entrypoint
# - Purpose: orchestrates interactive/headless setup flows and shared maintenance tasks.
# - Assumptions: config helpers are available under modules/config_service and HEADLESS is respected.
# - Side effects: reads/writes user config files, may invoke package managers, and prunes artifacts when requested.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PATH="$SCRIPT_DIR"
MODULE_DIR="$INSTALL_PATH/modules"
DEFAULT_CONFIG_FILE="$HOME/.config/aihub/installer.conf"
CONFIG_FILE="${CONFIG_FILE:-$DEFAULT_CONFIG_FILE}"
CONFIG_STATE_FILE="${CONFIG_STATE_FILE:-$HOME/.config/aihub/config.yaml}"
LOG_FILE="${LOG_FILE:-$HOME/.config/aihub/install.log}"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

source "$MODULE_DIR/config_service/config_helpers.sh"

HEADLESS_MODE=false
INSTALL_TARGET=""
GPU_MODE_OVERRIDE=""
USER_CONFIG_FILE=""
CONFIG_OVERRIDES=()
RUN_ARTIFACT_MAINT=false
PROFILE_NAME=""
CONFIG_SCHEMA_PATH="$MODULE_DIR/config_service/installer_schema.yaml"

log_msg() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$LOG_FILE"
}

log_error() {
  local message="$1"
  echo "[!] $message" | tee -a "$LOG_FILE" >&2
}

PLATFORM_KIND=""
DESKTOP_ENVIRONMENT=""
WINDOWS_DESKTOP_LINUX_PATH=""
WINDOWS_DESKTOP_WIN_PATH=""

detect_platform() {
  local uname_s
  uname_s=$(uname -s 2>/dev/null || echo "")

  case "$uname_s" in
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        PLATFORM_KIND="wsl"
      else
        PLATFORM_KIND="linux"
      fi
      ;;
    Darwin)
      PLATFORM_KIND="macos"
      ;;
    MINGW*|MSYS*|CYGWIN*)
      PLATFORM_KIND="windows"
      ;;
    *)
      PLATFORM_KIND="linux"
      ;;
  esac

  DESKTOP_ENVIRONMENT="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-Unknown}}"
  log_msg "Platform detected: ${PLATFORM_KIND} (desktop=${DESKTOP_ENVIRONMENT})"
}

determine_linux_desktop_dir() {
  local desktop_dir
  if command -v xdg-user-dir >/dev/null 2>&1; then
    desktop_dir=$(xdg-user-dir DESKTOP 2>/dev/null)
  fi

  desktop_dir="${desktop_dir:-$HOME/Desktop}"
  echo "$desktop_dir"
}

determine_windows_desktop_paths() {
  WINDOWS_DESKTOP_LINUX_PATH=""
  WINDOWS_DESKTOP_WIN_PATH=""

  local win_path=""
  if command -v powershell.exe >/dev/null 2>&1; then
    win_path=$(powershell.exe -NoProfile -Command "[Environment]::GetFolderPath('Desktop')" 2>/dev/null | tr -d '\\r')
  fi

  if [[ -z "$win_path" ]]; then
    local guess="/mnt/c/Users/$USER/Desktop"
    if [[ -d "$guess" ]]; then
      win_path="C:\\Users\\$USER\\Desktop"
      WINDOWS_DESKTOP_LINUX_PATH="$guess"
    fi
  fi

  if [[ -n "$win_path" ]]; then
    WINDOWS_DESKTOP_WIN_PATH="$win_path"
    if command -v wslpath >/dev/null 2>&1; then
      WINDOWS_DESKTOP_LINUX_PATH=$(wslpath -u "$win_path" 2>/dev/null)
    elif [[ -z "$WINDOWS_DESKTOP_LINUX_PATH" ]]; then
      local converted
      converted=$(printf '%s' "$win_path" | sed -E 's|^([A-Za-z]):|/mnt/\1|;s|\\\\|/|g')
      WINDOWS_DESKTOP_LINUX_PATH="$converted"
    fi
  fi
}

create_linux_desktop_entry() {
  local desktop_entry_path="$1"
  local launch_cmd="$2"

  mkdir -p "$(dirname "$desktop_entry_path")"
  cat > "$desktop_entry_path" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=AI Workstation Launcher
Comment=Launch the AI Workstation Menu
Exec=/bin/bash -lc '"$launch_cmd"'
Icon=utilities-terminal
Terminal=false
Categories=Utility;
EOF

  chmod +x "$desktop_entry_path"
  log_msg "Desktop launcher created at $desktop_entry_path"
}

create_windows_launchers() {
  local launch_cmd="$1"

  determine_windows_desktop_paths
  if [[ -z "$WINDOWS_DESKTOP_LINUX_PATH" ]]; then
    log_error "Unable to resolve Windows Desktop path; skipping Windows shortcut creation."
    return 1
  fi

  mkdir -p "$WINDOWS_DESKTOP_LINUX_PATH"
  local bat_path="$WINDOWS_DESKTOP_LINUX_PATH/AI-Hub-Launcher.bat"
  cat > "$bat_path" <<EOF
@echo off
wsl.exe -e bash -lc "cd '${launch_cmd%/*}' && '${launch_cmd}'"
EOF
  chmod +x "$bat_path"
  log_msg "Windows batch launcher created at $bat_path"

  local ps_path="$WINDOWS_DESKTOP_LINUX_PATH/AI-Hub-Launcher.ps1"
  cat > "$ps_path" <<EOF
Param()
$ErrorActionPreference = "Stop"
$repoPathWSL = "${launch_cmd%/*}"
wsl.exe -e bash -lc "cd \"$repoPathWSL\" && '${launch_cmd}'"
EOF
  log_msg "Windows PowerShell launcher created at $ps_path"

  if [[ -n "$WINDOWS_DESKTOP_WIN_PATH" ]]; then
    local repo_win_path=""
    if command -v wslpath >/dev/null 2>&1; then
      repo_win_path=$(wslpath -w "${launch_cmd%/*}" 2>/dev/null)
    fi

    powershell.exe -NoProfile -Command "try { $ws = New-Object -ComObject WScript.Shell; $shortcut = $ws.CreateShortcut('${WINDOWS_DESKTOP_WIN_PATH}\\AI Hub Launcher.lnk'); $shortcut.TargetPath = 'wsl.exe'; $shortcut.Arguments = '-e bash -lc ''cd ""${launch_cmd%/*}"" && ""${launch_cmd}""'''; $shortcut.WorkingDirectory = '${repo_win_path:-.}'; $shortcut.IconLocation = 'shell32.dll,217'; $shortcut.Save(); exit 0 } catch { exit 1 }" >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
      log_msg "Windows .lnk shortcut created at ${WINDOWS_DESKTOP_WIN_PATH}\\AI Hub Launcher.lnk"
    else
      log_error "Failed to create .lnk shortcut; PowerShell COM automation unavailable."
    fi
  fi
}

create_macos_launchers() {
  local launch_cmd="$1"
  local desktop_dir="$HOME/Desktop"
  local command_path="$desktop_dir/AI-Hub-Launcher.command"

  mkdir -p "$desktop_dir"
  cat > "$command_path" <<EOF
#!/bin/bash
cd "${launch_cmd%/*}" && /bin/bash "${launch_cmd}"
EOF
  chmod +x "$command_path"
  log_msg "macOS .command launcher created at $command_path"

  local app_dir="$HOME/Applications/AI Hub Launcher.app"
  mkdir -p "$app_dir/Contents/MacOS"
  cat > "$app_dir/Contents/MacOS/aihub_launcher" <<EOF
#!/bin/bash
cd "${launch_cmd%/*}" && /bin/bash "${launch_cmd}"
EOF
  chmod +x "$app_dir/Contents/MacOS/aihub_launcher"

  cat > "$app_dir/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>AI Hub Launcher</string>
  <key>CFBundleExecutable</key>
  <string>aihub_launcher</string>
  <key>CFBundleIdentifier</key>
  <string>com.aihub.launcher</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
</dict>
</plist>
EOF

  log_msg "macOS app bundle created at $app_dir"
}


CONFIG_STATE_BACKUP=""
CONFIG_ENV_BACKUP=""

backup_file_with_timestamp() {
  local src="$1"
  local dest=""
  if [[ -f "$src" ]]; then
    dest="${src}.$(date '+%Y%m%d-%H%M%S').bak"
    cp "$src" "$dest"
    log_msg "Created backup for $(basename "$src") at $dest"
  fi
  echo "$dest"
}

restore_backups() {
  [[ -n "$CONFIG_STATE_BACKUP" && -f "$CONFIG_STATE_BACKUP" ]] && cp "$CONFIG_STATE_BACKUP" "$CONFIG_STATE_FILE"
  [[ -n "$CONFIG_ENV_BACKUP" && -f "$CONFIG_ENV_BACKUP" ]] && cp "$CONFIG_ENV_BACKUP" "$CONFIG_FILE"
}

run_package_install() {
  local description="$1"
  shift
  local cmd=("$@")
  local attempts=0 max_attempts=2

  while (( attempts < max_attempts )); do
    attempts=$((attempts + 1))
    log_msg "Executing package command ($attempts/$max_attempts): ${cmd[*]} for ${description:-packages}"
    if "${cmd[@]}"; then
      log_msg "Package command succeeded for ${description:-packages}"
      return 0
    fi

    local exit_code=$?
    log_error "Package command failed or was canceled (exit $exit_code) for ${description:-packages}"
    if (( attempts >= max_attempts )); then
      break
    fi

    if command -v yad >/dev/null 2>&1; then
      yad --question --title="Retry ${description:-install}" --text="The last package command failed or was canceled.\nWould you like to retry?" --tooltip="If network was interrupted, connect and retry" --button="Yes!retry:0" --button="No:1"
      [[ $? -eq 0 ]] || break
    else
      read -rp "Retry ${description:-install}? [y/N]: " answer || break
      [[ "$answer" =~ ^[Yy]$ ]] || break
    fi
  done

  return 1
}

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --headless           Run without YAD prompts using config defaults.
  --config <file>      Path to a JSON or env-style config file used in headless mode.
  --profile <name>     Use a predefined installer profile (e.g. ci-basic) validated against the schema.
  --config-schema <path> Override the installer schema path (for custom CI pipelines).
  --install <target>   Install a component directly (e.g. webui, kobold, sillytavern, loras, models).
  --gpu <mode>         Force GPU mode (nvidia|amd|intel|cpu) and skip GPU prompts.
  --cleanup            Run artifact maintenance (prune caches, rotate logs, verify links) and exit.
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
    --profile)
      PROFILE_NAME="$2"
      shift
      ;;
    --config-schema)
      CONFIG_SCHEMA_PATH="$2"
      shift
      ;;
    --cleanup)
      RUN_ARTIFACT_MAINT=true
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

# Derive HEADLESS value for downstream scripts; exposed for called modules.
export HEADLESS=$([[ "$HEADLESS_MODE" == true ]] && echo 1 || echo 0)

if [[ "$HEADLESS_MODE" == true && -n "$USER_CONFIG_FILE" ]]; then
  CONFIG_FILE="$USER_CONFIG_FILE"
fi

# Snapshot user config before mutating values so failures can be rolled back safely.
CONFIG_STATE_BACKUP=$(backup_file_with_timestamp "$CONFIG_STATE_FILE")
CONFIG_ENV_BACKUP=$(backup_file_with_timestamp "$CONFIG_FILE")

if ! CONFIG_ENV_FILE="$CONFIG_FILE" CONFIG_STATE_FILE="$CONFIG_STATE_FILE" config_load "${CONFIG_OVERRIDES[@]}"; then
  log_error "Failed to load configuration from $CONFIG_STATE_FILE; restoring backups."
  restore_backups
  exit 1
fi
export CONFIG_ENV_FILE="$CONFIG_FILE"

# Short-circuit when running maintenance only, allowing CI jobs to reuse the installer shell.
if [[ "$RUN_ARTIFACT_MAINT" == true ]]; then
    ARTIFACT_MANAGER="$MODULE_DIR/shell/artifact_manager.sh"
  if [[ -x "$ARTIFACT_MANAGER" ]]; then
    HEADLESS=1 bash "$ARTIFACT_MANAGER" --auto --headless
  else
    echo "Artifact manager is missing at $ARTIFACT_MANAGER" >&2
    exit 1
  fi
  exit 0
fi

notify_prereq() {
  local message="$1"
  if command -v yad >/dev/null 2>&1; then
    yad --error --title="Missing Prerequisite" --text="$message" --width=400 --tooltip="See installer docs for remediation"
  else
    echo "[!] $message" >&2
  fi
}

require_commands() {
  local missing=()
  declare -A remediation
  remediation["bash"]="Install bash via your package manager (e.g., sudo apt install bash)"
  remediation["sudo"]="Install sudo and ensure your user is in the sudoers file"
  remediation["lspci"]="Install pciutils: sudo apt install pciutils"
  remediation["lsmod"]="Install kmod: sudo apt install kmod"
  remediation["yad"]="Install YAD for dialogs: sudo apt install yad"
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd — ${remediation[$cmd]:-Install via your package manager}")
    else
      log_msg "Prerequisite check passed for $cmd"
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    local joined
    joined=$(IFS=$'\n'; echo "${missing[*]}")
    notify_prereq "The following tools are required before running the installer:\n\n$joined\n\nHelp: https://github.com/AI-Hub/AI-Hub#prerequisites"
    exit 1
  fi
}

# Ensure we have the basics to prompt and install dependencies before proceeding
require_commands bash sudo lspci lsmod yad

mkdir -p "$INSTALL_PATH"
mkdir -p "$(dirname "$CONFIG_FILE")"
mkdir -p "$(dirname "$DESKTOP_ENTRY")"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$CONFIG_FILE"
touch "$LOG_FILE"
log_msg "Installer starting with LOG_FILE=$LOG_FILE"

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
  python_output=$(python3 - "$file" <<'PY' 2>/dev/null
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

load_validated_headless_config() {
  local args=("$MODULE_DIR/config_service/config_service.py" installer-profile --schema "$CONFIG_SCHEMA_PATH" --format env)
  [[ -n "$USER_CONFIG_FILE" ]] && args+=(--file "$USER_CONFIG_FILE")
  [[ -n "$PROFILE_NAME" ]] && args+=(--profile "$PROFILE_NAME")

  local python_output
  if ! python_output=$(python3 "${args[@]}"); then
    log_error "Installer configuration validation failed."
    [[ -n "$python_output" ]] && echo "$python_output" >&2
    exit 1
  fi

  declare -gA HEADLESS_CONFIG
  while IFS='=' read -r key value; do
    [[ -z "$key" ]] && continue
    HEADLESS_CONFIG[$key]="$value"
  done <<< "$python_output"
}

apply_headless_config() {
  [[ "$HEADLESS_MODE" != true && -z "$PROFILE_NAME" ]] && return

  load_validated_headless_config

  if [[ "$HEADLESS_MODE" == true ]]; then
    log_msg "Running installer in headless mode."
  fi

  if [[ -n "$PROFILE_NAME" ]]; then
    log_msg "Installer profile '${PROFILE_NAME}' loaded (schema: $CONFIG_SCHEMA_PATH)."
  elif [[ -n "$USER_CONFIG_FILE" ]]; then
    log_msg "Headless config supplied via --config: $CONFIG_FILE"
  else
    log_msg "Headless mode using default config path: $CONFIG_FILE"
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

  if [[ -n "$GPU_MODE_OVERRIDE" ]]; then
    config_set "gpu.mode" "$GPU_MODE_OVERRIDE"
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

  if [[ -n "$INSTALL_TARGET" ]]; then
    config_set "installer.install_target" "$INSTALL_TARGET"
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

apply_headless_config
export GPU_MODE_OVERRIDE

detect_platform

if [[ "$AIHUB_SKIP_INSTALL_STEPS" == "1" ]]; then
  log_msg "AIHUB_SKIP_INSTALL_STEPS set; stopping after configuration validation."
  exit 0
fi

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
  CONFIG_FILE="$CONFIG_FILE" HEADLESS=$HEADLESS GPU_MODE_OVERRIDE="$GPU_MODE_OVERRIDE" bash "$MODULE_DIR/shell/detect_gpu.sh"
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
launcher_note="Launcher creation skipped."

case "$PLATFORM_KIND" in
  linux)
    linux_desktop_dir=$(determine_linux_desktop_dir)
    desktop_entry_path="${DESKTOP_ENTRY:-$linux_desktop_dir/AI-Workstation-Launcher.desktop}"
    create_linux_desktop_entry "$desktop_entry_path" "$LAUNCH_CMD"
    echo "[✔] Desktop launcher created at $desktop_entry_path"
    launcher_note="Linux desktop entry created at $desktop_entry_path (desktop=${DESKTOP_ENVIRONMENT})"
    ;;
  wsl|windows)
    create_windows_launchers "$LAUNCH_CMD"
    launcher_note="Windows shortcuts created in ${WINDOWS_DESKTOP_LINUX_PATH:-<unknown>} (desktop env=${DESKTOP_ENVIRONMENT})"
    ;;
  macos)
    create_macos_launchers "$LAUNCH_CMD"
    launcher_note="macOS launchers created at $HOME/Desktop/AI-Hub-Launcher.command and $HOME/Applications/AI Hub Launcher.app"
    ;;
  *)
    log_error "Unsupported platform ${PLATFORM_KIND}; launcher creation skipped."
    ;;
esac

log_msg "$launcher_note"

if [[ -n "$INSTALL_TARGET" ]]; then
  case "$INSTALL_TARGET" in
    webui)
      log_msg "Headless install requested: webui"
        HEADLESS=$HEADLESS bash "$MODULE_DIR/shell/install_webui.sh"
      ;;
    kobold)
      log_msg "Headless install requested: kobold"
        HEADLESS=$HEADLESS bash "$MODULE_DIR/shell/install_kobold.sh"
      ;;
    sillytavern)
      log_msg "Headless install requested: sillytavern"
        HEADLESS=$HEADLESS bash "$MODULE_DIR/shell/install_sillytavern.sh"
      ;;
    loras)
      log_msg "Headless install requested: loras"
        HEADLESS=$HEADLESS bash "$MODULE_DIR/shell/install_loras.sh"
      ;;
    models)
      log_msg "Headless install requested: models (Hugging Face)"
        HEADLESS=$HEADLESS bash "$MODULE_DIR/shell/install_models.sh"
      ;;
    *)
      log_msg "Unknown install target: $INSTALL_TARGET"
      echo "Unknown install target: $INSTALL_TARGET" >&2
      ;;
  esac
fi
