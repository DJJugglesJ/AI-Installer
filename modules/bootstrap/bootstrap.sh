#!/usr/bin/env bash

# bootstrap.sh — cross-distro prerequisite installer

set -euo pipefail

HEADLESS=${HEADLESS:-0}

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
PACKAGE_MAP=()
EXTRA_PACKAGES=()

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
    PACKAGE_MAP=(
      "git:git"
      "curl:curl"
      "jq:jq"
      "yad:yad"
      "python3:python3"
      "pip3:python3-pip"
      "node:nodejs"
      "npm:npm"
      "aria2c:aria2"
      "wget:wget"
    )
    EXTRA_PACKAGES=("ubuntu-drivers-common" "mesa-utils")
    ;;
  arch)
    PKG_MGR="pacman"
    UPDATE_CMD="sudo pacman -Sy"
    INSTALL_CMD="sudo pacman -S --noconfirm --needed"
    PACKAGE_MAP=(
      "git:git"
      "curl:curl"
      "jq:jq"
      "yad:yad"
      "python:python"
      "pip:python-pip"
      "node:nodejs"
      "npm:npm"
      "aria2c:aria2"
      "wget:wget"
    )
    EXTRA_PACKAGES=("mesa-utils" "vulkan-tools")
    ;;
  fedora|rhel|centos)
    PKG_MGR="dnf"
    UPDATE_CMD="sudo dnf makecache"
    INSTALL_CMD="sudo dnf install -y"
    PACKAGE_MAP=(
      "git:git"
      "curl:curl"
      "jq:jq"
      "yad:yad"
      "python3:python3"
      "pip3:python3-pip"
      "node:nodejs"
      "npm:npm"
      "aria2c:aria2"
      "wget:wget"
    )
    EXTRA_PACKAGES=("mesa-dri-drivers" "vulkan-tools")
    ;;
  *)
    case "$ID_LIKE_LOWER" in
      *debian*)
        PKG_MGR="apt"
        UPDATE_CMD="sudo apt update"
        INSTALL_CMD="sudo apt install -y"
        PACKAGE_MAP=(
          "git:git"
          "curl:curl"
          "jq:jq"
          "yad:yad"
          "python3:python3"
          "pip3:python3-pip"
          "node:nodejs"
          "npm:npm"
          "aria2c:aria2"
          "wget:wget"
        )
        EXTRA_PACKAGES=("ubuntu-drivers-common" "mesa-utils")
        ;;
      *arch*)
        PKG_MGR="pacman"
        UPDATE_CMD="sudo pacman -Sy"
        INSTALL_CMD="sudo pacman -S --noconfirm --needed"
        PACKAGE_MAP=(
          "git:git"
          "curl:curl"
          "jq:jq"
          "yad:yad"
          "python:python"
          "pip:python-pip"
          "node:nodejs"
          "npm:npm"
          "aria2c:aria2"
          "wget:wget"
        )
        EXTRA_PACKAGES=("mesa-utils" "vulkan-tools")
        ;;
      *fedora*|*rhel*|*centos*)
        PKG_MGR="dnf"
        UPDATE_CMD="sudo dnf makecache"
        INSTALL_CMD="sudo dnf install -y"
        PACKAGE_MAP=(
          "git:git"
          "curl:curl"
          "jq:jq"
          "yad:yad"
          "python3:python3"
          "pip3:python3-pip"
          "node:nodejs"
          "npm:npm"
          "aria2c:aria2"
          "wget:wget"
        )
        EXTRA_PACKAGES=("mesa-dri-drivers" "vulkan-tools")
        ;;
      *)
        ;;
    esac
    ;;
 esac

if [[ -z "$PKG_MGR" ]]; then
  warn "Unsupported distribution. Please install git, curl, jq, yad, python (with pip), nodejs/npm, aria2, wget, and GPU helpers manually."
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

for mapping in "${PACKAGE_MAP[@]}"; do
  IFS=":" read -r cmd pkg <<<"$mapping"
  if command -v "$cmd" >/dev/null 2>&1; then
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
  else
    missing_packages+=("$pkg")
  fi
 done

for extra in "${EXTRA_PACKAGES[@]}"; do
  if ! package_installed "$extra"; then
    missing_packages+=("$extra")
  fi
 done

if [[ ${#missing_packages[@]} -eq 0 ]]; then
  log "All bootstrap dependencies are already installed."
  exit 0
fi

unique_missing=($(printf "%s\n" "${missing_packages[@]}" | awk '!x[$0]++'))

log "Missing packages detected: ${unique_missing[*]}"

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
for mapping in "${PACKAGE_MAP[@]}"; do
  IFS=":" read -r cmd pkg <<<"$mapping"
  if command -v "$cmd" >/dev/null 2>&1; then
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
  fi
 done

log "Bootstrap complete."
