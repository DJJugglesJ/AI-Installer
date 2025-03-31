#!/bin/bash

# check_dependencies.sh — Ensure required packages are installed

REQUIRED=(git curl jq yad python3 python3-pip wget)
MISSING=()

echo "[*] Checking for required packages..."

for pkg in "${REQUIRED[@]}"; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    MISSING+=("$pkg")
  fi
done

if [ ${#MISSING[@]} -eq 0 ]; then
  echo "[✔] All dependencies are already installed."
else
  LIST=$(IFS=, ; echo "${MISSING[*]}")
  yad --question --title="Missing Dependencies" \
    --text="The following packages are required and will be installed:\n\n$LIST\n\nProceed with installation?" \
    --button="Yes!install:0" --button="Cancel:1"
  if [[ $? -eq 0 ]]; then
    sudo apt update
    sudo apt install -y "${MISSING[@]}"
  else
    yad --error --title="Cancelled" --text="Installation aborted due to missing dependencies."
    exit 1
  fi
fi
