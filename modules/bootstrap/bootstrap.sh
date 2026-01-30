#!/usr/bin/env bash

# bootstrap.sh — cross-distro prerequisite installer

set -euo pipefail

HEADLESS=${HEADLESS:-0}
INSTALL_TARGET="${AIHUB_INSTALL_TARGET:-}"

log() {
  echo "[bootstrap] $1"
}

warn() {
  echo "[bootstrap][warn] $1" >&2
}

# Detect distribution and set package manager details
PKG_MGR=""
UPDATE_CMD=""
INSTALL_CMD=""
BASE_PACKAGE_MAP=()
NODE_PACKAGE_MAP=()
GUI_PACKAGE_MAP=()
DESKTOP_PACKAGES=()

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
fi

ID_LIKE_LOWER="${ID_LIKE,,}" 2>/dev/null || ID_LIKE_LOWER=""
ID_LOWER="${ID,,}" 2>/dev/null || ID_LOWER=""

case "$ID_LOWER" in
  ubuntu|debian)
    PKG_MGR="apt"
    UPDATE_CMD="sudo apt update"
    INSTALL_CMD="sudo apt install -y"
    BASE_PACKAGE_MAP=(
      "git:git"
      "curl:curl"
      "jq:jq"
      "python3:python3"
      "pip3:python3-pip"
      "aria2c:aria2"
      "wget:wget"
    )
    NODE_PACKAGE_MAP=(
      "node:nodejs"
      "npm:npm"
    )
    GUI_PACKAGE_MAP=(
      "yad:yad"
    )
    DESKTOP_PACKAGES=("ubuntu-drivers-common" "mesa-utils")
    ;;
  arch)
    PKG_MGR="pacman"
    UPDATE_CMD="sudo pacman -Sy"
    INSTALL_CMD="sudo pacman -S --noconfirm --needed"
    BASE_PACKAGE_MAP=(
      "git:git"
      "curl:curl"
      "jq:jq"
      "python:python"
      "pip:python-pip"
      "aria2c:aria2"
      "wget:wget"
    )
    NODE_PACKAGE_MAP=(
      "node:nodejs"
      "npm:npm"
    )
    GUI_PACKAGE_MAP=(
      "yad:yad"
    )
    DESKTOP_PACKAGES=("mesa-utils" "vulkan-tools")
    ;;
  fedora|rhel|centos)
    PKG_MGR="dnf"
    UPDATE_CMD="sudo dnf makecache"
    INSTALL_CMD="sudo dnf install -y"
    BASE_PACKAGE_MAP=(
      "git:git"
      "curl:curl"
      "jq:jq"
      "python3:python3"
      "pip3:python3-pip"
      "aria2c:aria2"
      "wget:wget"
    )
    NODE_PACKAGE_MAP=(
      "node:nodejs"
      "npm:npm"
    )
    GUI_PACKAGE_MAP=(
      "yad:yad"
    )
    DESKTOP_PACKAGES=("mesa-dri-drivers" "vulkan-tools")
    ;;
  *)
    case "$ID_LIKE_LOWER" in
      *debian*)
        PKG_MGR="apt"
        UPDATE_CMD="sudo apt update"
        INSTALL_CMD="sudo apt install -y"
        BASE_PACKAGE_MAP=(
          "git:git"
          "curl:curl"
          "jq:jq"
          "python3:python3"
          "pip3:python3-pip"
          "aria2c:aria2"
          "wget:wget"
        )
        NODE_PACKAGE_MAP=(
          "node:nodejs"
          "npm:npm"
        )
        GUI_PACKAGE_MAP=(
          "yad:yad"
        )
        DESKTOP_PACKAGES=("ubuntu-drivers-common" "mesa-utils")
        ;;
      *arch*)
        PKG_MGR="pacman"
        UPDATE_CMD="sudo pacman -Sy"
        INSTALL_CMD="sudo pacman -S --noconfirm --needed"
        BASE_PACKAGE_MAP=(
          "git:git"
          "curl:curl"
          "jq:jq"
          "python:python"
          "pip:python-pip"
          "aria2c:aria2"
          "wget:wget"
        )
        NODE_PACKAGE_MAP=(
          "node:nodejs"
          "npm:npm"
        )
        GUI_PACKAGE_MAP=(
          "yad:yad"
        )
        DESKTOP_PACKAGES=("mesa-utils" "vulkan-tools")
        ;;
      *fedora*|*rhel*|*centos*)
        PKG_MGR="dnf"
        UPDATE_CMD="sudo dnf makecache"
        INSTALL_CMD="sudo dnf install -y"
        BASE_PACKAGE_MAP=(
          "git:git"
          "curl:curl"
          "jq:jq"
          "python3:python3"
          "pip3:python3-pip"
          "aria2c:aria2"
          "wget:wget"
        )
        NODE_PACKAGE_MAP=(
          "node:nodejs"
          "npm:npm"
        )
        GUI_PACKAGE_MAP=(
          "yad:yad"
        )
        DESKTOP_PACKAGES=("mesa-dri-drivers" "vulkan-tools")
        ;;
      *)
        ;;
    esac
    ;;
 esac

if [[ -z "$PKG_MGR" ]]; then
  warn "Unsupported distribution. Please install git, curl, jq, python (with pip), aria2, wget, and any required GUI/node/GPU helpers manually."
  warn "Common commands: Ubuntu/Debian=apt, Fedora/RHEL=dnf, Arch=pacman."
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  warn "sudo is required to install packages automatically. Please install prerequisites manually."
  exit 1
fi

package_installed() {
  local pkg="$1"
  case "$PKG_MGR" in
    apt) dpkg -s "$pkg" >/dev/null 2>&1 ;;
    pacman) pacman -Q "$pkg" >/dev/null 2>&1 ;;
    dnf) rpm -q "$pkg" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

missing_packages=()
missing_base=()
missing_gui=()
missing_node=()
missing_desktop=()

require_node=1
if [[ -n "$INSTALL_TARGET" ]]; then
  case "${INSTALL_TARGET,,}" in
    sillytavern) require_node=1 ;;
    *) require_node=0 ;;
  esac
fi

require_gui=1
require_desktop=1
if [[ "$HEADLESS" -eq 1 ]]; then
  require_gui=0
  require_desktop=0
fi

if [[ "$require_node" -eq 1 ]]; then
  log "Node.js/npm required for install target '${INSTALL_TARGET:-default}'."
else
  log "Node.js/npm not required for install target '${INSTALL_TARGET:-default}'; skipping."
fi

if [[ "$HEADLESS" -eq 1 ]]; then
  log "Headless mode: skipping GUI/desktop-only packages unless required by install target."
fi

log_command_version() {
  local cmd="$1"
  case "$cmd" in
    git) log "git version $(git --version 2>/dev/null | head -n1)" ;;
    curl) log "curl version $(curl --version 2>/dev/null | head -n1)" ;;
    jq) log "jq version $(jq --version 2>/dev/null)" ;;
    python3|python) log "python version $($cmd --version 2>/dev/null)" ;;
    pip3|pip) log "pip version $($cmd --version 2>/dev/null)" ;;
    node) log "node version $(node --version 2>/dev/null)" ;;
    npm) log "npm version $(npm --version 2>/dev/null)" ;;
    aria2c) log "aria2 version $(aria2c --version 2>/dev/null | head -n1)" ;;
    wget) log "wget version $(wget --version 2>/dev/null | head -n1)" ;;
    yad) log "yad present (version check deferred)" ;;
    *) ;;
  esac
}

collect_missing_from_map() {
  local -n map_ref=$1
  local -n missing_ref=$2
  for mapping in "${map_ref[@]}"; do
    IFS=":" read -r cmd pkg <<<"$mapping"
    if command -v "$cmd" >/dev/null 2>&1; then
      log_command_version "$cmd"
    else
      missing_ref+=("$pkg")
      missing_packages+=("$pkg")
    fi
  done
}

log_versions_from_map() {
  local -n map_ref=$1
  for mapping in "${map_ref[@]}"; do
    IFS=":" read -r cmd pkg <<<"$mapping"
    if command -v "$cmd" >/dev/null 2>&1; then
      log_command_version "$cmd"
    fi
  done
}

collect_missing_from_map BASE_PACKAGE_MAP missing_base

if [[ "$require_node" -eq 1 ]]; then
  collect_missing_from_map NODE_PACKAGE_MAP missing_node
fi

if [[ "$require_gui" -eq 1 ]]; then
  collect_missing_from_map GUI_PACKAGE_MAP missing_gui
fi

if [[ "$require_desktop" -eq 1 ]]; then
  for extra in "${DESKTOP_PACKAGES[@]}"; do
    if ! package_installed "$extra"; then
      missing_desktop+=("$extra")
      missing_packages+=("$extra")
    fi
  done
fi

if [[ ${#missing_packages[@]} -eq 0 ]]; then
  log "All bootstrap dependencies are already installed."
  exit 0
fi

unique_missing=($(printf "%s\n" "${missing_packages[@]}" | awk '!x[$0]++'))

log "Missing packages detected: ${unique_missing[*]}"

if [[ ${#missing_base[@]} -gt 0 ]]; then
  log "Package group [base]: ${missing_base[*]}"
fi
if [[ ${#missing_node[@]} -gt 0 ]]; then
  log "Package group [node]: ${missing_node[*]}"
fi
if [[ ${#missing_gui[@]} -gt 0 ]]; then
  log "Package group [gui]: ${missing_gui[*]}"
fi
if [[ ${#missing_desktop[@]} -gt 0 ]]; then
  log "Package group [desktop]: ${missing_desktop[*]}"
fi

if [[ "$HEADLESS" -eq 1 ]]; then
  log "Headless mode: installing missing packages automatically."
else
  read -r -p "Install missing packages with $PKG_MGR? [Y/n] " reply
  reply=${reply:-Y}
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    warn "User declined automatic installation. Please install: ${unique_missing[*]}"
    exit 1
  fi
fi

log "Updating package index with: $UPDATE_CMD"
if ! eval "$UPDATE_CMD"; then
  warn "Failed to update package index. Please run '$UPDATE_CMD' manually and retry."
  exit 1
fi

log "Installing packages: ${unique_missing[*]}"
if ! eval "$INSTALL_CMD ${unique_missing[*]}"; then
  warn "Automatic installation failed. Install the following manually using $PKG_MGR: ${unique_missing[*]}"
  exit 1
fi

log "Bootstrap dependencies installed successfully."

# Re-log versions for newly installed commands
log_versions_from_map BASE_PACKAGE_MAP

if [[ "$require_node" -eq 1 ]]; then
  log_versions_from_map NODE_PACKAGE_MAP
fi

if [[ "$require_gui" -eq 1 ]]; then
  log_versions_from_map GUI_PACKAGE_MAP
fi

log "Bootstrap complete."
